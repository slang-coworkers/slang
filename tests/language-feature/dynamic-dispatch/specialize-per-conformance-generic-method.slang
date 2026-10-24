//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cpu -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-dx12 -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -shaderobj -output-using-type
//TEST:SIMPLE(filecheck=HLSL):-target hlsl -entry computeMain -conformance A:IValue=3 -conformance B:IValue=7
//TEST:SIMPLE(filecheck=SPIRV):-target spirv -entry computeMain -conformance A:IValue=3 -conformance B:IValue=7

// Methods of `extension<T : IValue> T` with their own generic parameters lower to a
// generic nested inside the extension's generic. Static arguments for the method's
// parameters still yield one copy of the method per conforming type, and the copy
// for a type is the same function a static call produces; a second dynamic type
// keeps the ordinary shared body.

interface IValue { uint get(); }
interface IHandler { uint handle(uint v); }

struct A : IValue
{
    uint value;
    uint get() { return value; }
}

struct B : IValue
{
    uint value;
    uint get() { return value * 2; }
}

struct AddHundred : IHandler { uint handle(uint v) { return v + 100; } }

struct Box<let N : uint> { uint value; }

uint readMarker(inout uint state) { return state++; }

extension<T : IValue> T
{
    void consume<let Bias : uint = 4>(inout uint result) { result = this.get() + Bias; }

    uint apply<H : IHandler>(H handler, inout uint state)
    {
        return handler.handle(this.get() + readMarker(state));
    }

    void store<let F : uint>(inout Box<F> box) { box.value = this.get() * 10 + F; }

    void pair<U : IValue>(U other, out uint result) { result = this.get() * 10 + other.get(); }

    // One counter per type: a dynamic and a static call for A share A's copy.
    uint count<let Step : uint>()
    {
        static uint counter = 0;
        counter += Step;
        return counter;
    }
}

//TEST_INPUT: type_conformance A:IValue = 3
//TEST_INPUT: type_conformance B:IValue = 7
//TEST_INPUT:ubuffer(data=[3 7], stride=4):name=ids
//TEST_INPUT:ubuffer(data=[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0], stride=4):out,name=outputBuffer
StructuredBuffer<uint> ids;
RWStructuredBuffer<uint> outputBuffer;

[shader("compute")]
[numthreads(2, 1, 1)]
void computeMain(uint3 tid : SV_DispatchThreadID)
{
    let value = createDynamicObject<IValue>(ids[tid.x], 5u);
    uint offset = tid.x * 8;
    uint result = 0;
    value.consume(result);
    outputBuffer[offset] = result;
    uint state = 20;
    outputBuffer[offset + 1] = value.apply(AddHundred(), state);
    outputBuffer[offset + 2] = state;
    Box<7> box;
    value.store(box);
    outputBuffer[offset + 3] = box.value;
    value.pair(createDynamicObject<IValue>(ids[1 - tid.x], 2u), result);
    outputBuffer[offset + 4] = result;
    value.consume<1>(result);
    outputBuffer[offset + 5] = result;
    outputBuffer[offset + 6] = value.count<3>();
    A a = { 1 };
    outputBuffer[offset + 7] = a.count<3>();
}

// CHECK: 9
// CHECK: 125
// CHECK: 21
// CHECK: 57
// CHECK: 54
// CHECK: 6
// CHECK: 3
// CHECK: 6
// CHECK: 14
// CHECK: 130
// CHECK: 21
// CHECK: 107
// CHECK: 102
// CHECK: 11
// CHECK: 3
// CHECK: 3

// Each copy of `apply` reads the marker and handles the result for one type, while
// `pair` keeps one body that takes the tags of both dynamic types.
// HLSL: uint apply_{{[0-9]+}}(
// HLSL: = readMarker
// HLSL: AddHundred_handle
// HLSL: uint apply_{{[0-9]+}}(
// HLSL: = readMarker
// HLSL: AddHundred_handle
// HLSL: void pair_{{[0-9]+}}(uint {{.*}}, uint
// SPIRV: OpEntryPoint GLCompute
