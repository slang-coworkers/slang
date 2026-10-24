// The generic extension `extension<T : IInterface> T` adds methods to concrete types
// conforming to IInterface without extending the interface itself. Slang 2025
// disallows specializing a generic with an existential, but a method of this
// extension is the exception: calling it on an interface-typed value specializes
// the method once per conforming type, like a dispatch of an interface method.
// An ordinary generic function called with the same value is still an error.

//TEST:SIMPLE(filecheck=CHECK): -target spirv
//TEST:SIMPLE(filecheck=CHECK): -target hlsl -stage compute -entry computeMain
//TEST:SIMPLE(filecheck=CHECK): -target glsl -stage compute -entry computeMain
//TEST:SIMPLE(filecheck=HLSL): -target hlsl -stage compute -entry computeMain -DEXTENSION_ONLY

#lang slang 2025

RWStructuredBuffer<float> outputBuffer;

interface IInterface
{
    float calc(float x);
}

struct A : IInterface
{
    float calc(float x) { return x * x * x; }
};

struct B : IInterface
{
    float calc(float x) { return x * x; }
};

extension<T : IInterface> T
{
    float calcTwice(float x)
    {
        return this.calc(x) + this.calc(x);
    }
}

float calcTwiceGeneric<T : IInterface>(T obj, float x)
{
    return obj.calc(x) + obj.calc(x);
}

IInterface factoryAB(uint id, float x)
{
    if (id == 0)
        return A();
    else
        return B();
}

float calcTwice(IInterface obj, float y)
{
#ifdef EXTENSION_ONLY
    return obj.calcTwice(y);
#else
    // Only the ordinary generic function is diagnosed.
    // CHECK: error[E33180]
    // CHECK: specializing 'calcTwiceGeneric' with an existential type
    // CHECK-NOT: error[E33180]
    return obj.calcTwice(y) + calcTwiceGeneric(obj, y);
#endif
}

float f(uint id, float x)
{
    IInterface obj = factoryAB(id, x);
    return calcTwice(obj, x);
}

[numthreads(1, 1, 1)]
void computeMain(uint3 dispatchThreadID : SV_DispatchThreadID)
{
    outputBuffer[0] = f(0, 3);
    outputBuffer[1] = f(1, 3);
}

// One copy of calcTwice per conforming type, each calling its own calc directly.
// HLSL: float calcTwice_[[N0:[0-9]+]](float
// HLSL-NEXT: {
// HLSL: _calc_
// HLSL: float calcTwice_[[N1:[0-9]+]](float
// HLSL-NEXT: {
// HLSL: _calc_
