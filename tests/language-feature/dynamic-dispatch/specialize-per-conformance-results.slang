//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cpu -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-dx12 -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -shaderobj -output-using-type
//TEST:SIMPLE(filecheck=HLSL):-target hlsl -entry computeMain -conformance A:IValue=3 -conformance B:IValue=7
//TEST:SIMPLE(filecheck=SPIRV):-target spirv -entry computeMain -conformance A:IValue=3 -conformance B:IValue=7
//TEST:SIMPLE(filecheck=HLSL):-target hlsl -entry computeMain -conformance A:IValue=3 -conformance B:IValue=7 -DLANG2025

// A shared body would give the same buffer values, so the HLSL checks look for one copy of
// each method per type, and the Slang 2025 run compiles only if every copy was formed.
#ifdef LANG2025
#lang slang 2025
#endif

interface IValue { uint get(); }
struct A : IValue { uint get() { return 2; } }
struct B : IValue { uint get() { return 5; } }
struct Result { uint value; float weight; }

uint readMarker(inout uint state) { return state++; }

extension<T : IValue> T
{
    Result result(inout uint state)
    {
        uint marker = readMarker(state);
        return {this.get() + marker, float(this.get()) * 0.5};
    }

    bool positive() { return this.get() > 0; }

    float weight() { return float(this.get()) * 0.5; }
}

//TEST_INPUT: type_conformance A:IValue = 3
//TEST_INPUT: type_conformance B:IValue = 7
//TEST_INPUT:ubuffer(data=[3 7], stride=4):name=ids
//TEST_INPUT:ubuffer(data=[0 0 0 0 0 0], stride=4):out,name=outputBuffer
StructuredBuffer<uint> ids;
RWStructuredBuffer<uint> outputBuffer;
[shader("compute")]
[numthreads(2, 1, 1)]
void computeMain(uint3 tid : SV_DispatchThreadID)
{
    let v = createDynamicObject<IValue>(ids[tid.x], 0u);
    uint state = 10;
    Result r = v.result(state);
    outputBuffer[tid.x * 3] = r.value;
    outputBuffer[tid.x * 3 + 1] = state;
    outputBuffer[tid.x * 3 + 2] = uint(r.weight == v.weight() && v.positive());
}
// CHECK: 12
// CHECK: 11
// CHECK: 1
// CHECK: 15
// CHECK: 11
// CHECK: 1
// HLSL-COUNT-2: bool positive_{{[0-9]+}}()
// HLSL-COUNT-2: float weight_{{[0-9]+}}()
// HLSL-COUNT-2: = readMarker
// SPIRV: OpEntryPoint GLCompute
