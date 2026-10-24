//DIAGNOSTIC_TEST:SIMPLE(diag=RESULT):-target hlsl -entry computeMain -DCASE=0 -conformance A:IValue=3 -conformance B:IValue=7
//DIAGNOSTIC_TEST:SIMPLE(diag=REFERENCE):-target hlsl -entry computeMain -DCASE=1 -conformance A:IValue=3 -conformance B:IValue=7
//DIAGNOSTIC_TEST:SIMPLE(diag=ORDINARY):-target hlsl -entry computeMain -DCASE=2 -conformance A:IValue=3 -conformance B:IValue=7

// Slang 2025 disallows specializing a generic with an existential. The target
// parameter of `extension<T : IValue> T` is the exception because its set of types
// is specialized once per type; a method whose signature changes with T cannot be
// split that way, so it keeps the error, as does an ordinary generic function.
#lang slang 2025

interface IValue { uint get(); [mutating] void bump(); }
struct A : IValue { uint v; uint get() { return 2; } [mutating] void bump() { v++; } }
struct B : IValue { uint v; uint get() { return 5; } [mutating] void bump() { v += 2; } }

extension<T : IValue> T
{
    T changingResult() { return this; }
    [mutating] void reference() { this.bump(); }
}

uint ordinary<T : IValue>(T value) { return value.get(); }

RWStructuredBuffer<uint> outputBuffer;
[shader("compute")]
[numthreads(1, 1, 1)]
void computeMain(uint3 tid : SV_DispatchThreadID)
{
    var a = createDynamicObject<IValue>(tid.x, 0u);
#if CASE == 0
    outputBuffer[tid.x] = a.changingResult().get();
//RESULT:                                 ^ cannot specialize generic with existential type
//RESULT:                                 ^ specializing 'changingResult' with an existential type is not allowed. All generic arguments must be statically resolvable at compile time.
#elif CASE == 1
    a.reference();
//REFERENCE:   ^ cannot specialize generic with existential type
//REFERENCE:   ^ specializing 'reference' with an existential type is not allowed. All generic arguments must be statically resolvable at compile time.
    outputBuffer[tid.x] = a.get();
#else
    outputBuffer[tid.x] = ordinary(a);
//ORDINARY:                       ^ cannot specialize generic with existential type
//ORDINARY:                       ^ specializing 'ordinary' with an existential type is not allowed. All generic arguments must be statically resolvable at compile time.
#endif
}
