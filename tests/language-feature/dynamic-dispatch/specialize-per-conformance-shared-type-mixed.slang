//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cpu -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -shaderobj -output-using-type
//TEST:SIMPLE(filecheck=HLSL):-target hlsl -entry computeMain -conformance Number<0>:ICode=0 -conformance Number<1>:ICode=1 -conformance Other:ICode=2 -DLANG2025

// `Number<0>` and `Number<1>` are one IR type (see specialize-per-conformance-shared-type.slang)
// and `Other` has its own, so `T` receives a set of two types with three witnesses. With one
// constraint, each witness still gets its own copy of the method.
#ifdef LANG2025
#lang slang 2025
#endif

interface ICode
{
    static uint code();
}

struct Number<let N : uint> : ICode
{
    static uint code() { return N; }
}

struct Other : ICode
{
    uint pad;
    static uint code() { return 7; }
}

extension<T : ICode> T
{
    uint codeOf() { return T.code() * 10; }
}

//TEST_INPUT: type_conformance Number<0>:ICode = 0
//TEST_INPUT: type_conformance Number<1>:ICode = 1
//TEST_INPUT: type_conformance Other:ICode = 2
//TEST_INPUT:ubuffer(data=[0 0 0], stride=4):out,name=outputBuffer
RWStructuredBuffer<uint> outputBuffer;

[shader("compute")]
[numthreads(3, 1, 1)]
void computeMain(uint3 tid : SV_DispatchThreadID)
{
    outputBuffer[tid.x] = createDynamicObject<ICode>(tid.x, 0u).codeOf();
}

// CHECK: 0
// CHECK: 10
// CHECK: 70
// HLSL-COUNT-3: uint codeOf_{{[0-9]+}}(
// HLSL-NOT: uint codeOf_{{[0-9]+}}(
