//DIAGNOSTIC_TEST:SIMPLE(diag=CHECK):-target hlsl -entry computeMain -conformance A:IValue=0 -conformance B:IValue=1 -DPACK_SIZE=0
//DIAGNOSTIC_TEST:SIMPLE(diag=CHECK):-target hlsl -entry computeMain -conformance A:IValue=0 -conformance B:IValue=1 -DPACK_SIZE=1
//TEST:SIMPLE(filecheck=LEGACY):-target hlsl -entry computeMain -conformance A:IValue=0 -conformance B:IValue=1 -DPACK_SIZE=1 -DLEGACY

// Specialization expands an empty pack away and unwraps a singleton pack, so the
// signature of a concrete copy no longer matches the dispatcher. The method keeps
// the shared body, which Slang 2025 rejects as specialization with an existential;
// legacy mode compiles the shared body.
#ifndef LEGACY
#lang slang 2025
#endif

interface IValue { uint get(); }
struct A : IValue { uint get() { return 2; } }
struct B : IValue { uint get() { return 5; } }

extension<T : IValue> T
{
    uint helper<each U>(expand each U args) { return this.get(); }
//CHECK: ^^^^^^ cannot specialize generic with existential type
//CHECK: ^^^^^^ specializing 'helper' with an existential type is not allowed. All generic arguments must be statically resolvable at compile time.
}

RWStructuredBuffer<uint> outputBuffer;
[shader("compute")]
[numthreads(1, 1, 1)]
void computeMain(uint3 tid : SV_DispatchThreadID)
{
    let value = createDynamicObject<IValue>(tid.x, 0u);
#if PACK_SIZE == 0
    outputBuffer[tid.x] = value.helper();
#else
    outputBuffer[tid.x] = value.helper(tid.y);
#endif
}

// LEGACY: uint helper_0(uint
// LEGACY-NOT: uint helper_1(
