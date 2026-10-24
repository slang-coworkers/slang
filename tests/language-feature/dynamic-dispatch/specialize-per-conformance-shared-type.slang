//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cpu -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -shaderobj -output-using-type
//TEST:SIMPLE(filecheck=HLSL):-target hlsl -entry computeMain -conformance Number<0>:ICode=0 -conformance Number<1>:ICode=1 -conformance Number<2>:ICode=2 -DLANG2025

// Empty specializations of one generic struct are one IR type: removeUnusedGenericParam
// hoists a struct that does not use its generic parameters out of its generic. `T` then
// receives that single type while its witnesses still tell the conformers apart. With one
// constraint, the method still gets one copy per conformer, keyed by witness.
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

extension<T : ICode> T
{
    uint codeOf() { return T.code() * 10; }
}

//TEST_INPUT: type_conformance Number<0>:ICode = 0
//TEST_INPUT: type_conformance Number<1>:ICode = 1
//TEST_INPUT: type_conformance Number<2>:ICode = 2
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
// CHECK: 20
// HLSL-COUNT-3: uint codeOf_{{[0-9]+}}()
// HLSL-NOT: uint codeOf_{{[0-9]+}}()
