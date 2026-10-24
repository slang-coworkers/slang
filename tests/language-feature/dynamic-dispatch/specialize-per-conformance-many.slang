//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cpu -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-dx12 -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -shaderobj -output-using-type
//TEST:SIMPLE(filecheck=HLSL):-target hlsl -entry computeMain -conformance Number<0>:ICode=0 -conformance Number<1>:ICode=1 -conformance Number<2>:ICode=2 -conformance Number<3>:ICode=3 -conformance Number<4>:ICode=4 -conformance Number<5>:ICode=5 -conformance Number<6>:ICode=6 -conformance Number<7>:ICode=7 -conformance Number<8>:ICode=8
//TEST:SIMPLE(filecheck=HLSL):-target hlsl -entry computeMain -conformance Number<0>:ICode=0 -conformance Number<1>:ICode=1 -conformance Number<2>:ICode=2 -conformance Number<3>:ICode=3 -conformance Number<4>:ICode=4 -conformance Number<5>:ICode=5 -conformance Number<6>:ICode=6 -conformance Number<7>:ICode=7 -conformance Number<8>:ICode=8 -DLANG2025

// Nine conformers that are specializations of one generic struct. Per-conformance
// specialization has no size limit, so each conformer gets its own copy; the
// Slang 2025 run compiles only if every copy was formed.
#ifdef LANG2025
#lang slang 2025
#endif

interface ICode
{
    static uint code();
}

// The field depends on N, so the nine specializations stay distinct types.
struct Number<let N : uint> : ICode
{
    uint digits[N + 1];
    static uint code() { return N; }
}

uint readMarker(inout uint state)
{
    return state++;
}

extension<T : ICode> T
{
    void getCode(inout uint state)
    {
        uint context = readMarker(state);
        state = T.code() + context;
    }
}

//TEST_INPUT: type_conformance Number<0>:ICode = 0
//TEST_INPUT: type_conformance Number<1>:ICode = 1
//TEST_INPUT: type_conformance Number<2>:ICode = 2
//TEST_INPUT: type_conformance Number<3>:ICode = 3
//TEST_INPUT: type_conformance Number<4>:ICode = 4
//TEST_INPUT: type_conformance Number<5>:ICode = 5
//TEST_INPUT: type_conformance Number<6>:ICode = 6
//TEST_INPUT: type_conformance Number<7>:ICode = 7
//TEST_INPUT: type_conformance Number<8>:ICode = 8
//TEST_INPUT:ubuffer(data=[0 0 0 0 0 0 0 0 0], stride=4):out,name=outputBuffer
RWStructuredBuffer<uint> outputBuffer;

[shader("compute")]
[numthreads(9, 1, 1)]
void computeMain(uint3 tid : SV_DispatchThreadID)
{
    uint state = 0;
    createDynamicObject<ICode>(tid.x, 0u).getCode(state);
    outputBuffer[tid.x] = state;
}

// CHECK: 0
// CHECK: 1
// CHECK: 2
// CHECK: 3
// CHECK: 4
// CHECK: 5
// CHECK: 6
// CHECK: 7
// CHECK: 8
// HLSL-COUNT-9: = readMarker
// HLSL-NOT: = readMarker
