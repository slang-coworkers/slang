//DIAGNOSTIC_TEST:SIMPLE(diag=RESULT):-target hlsl -entry computeMain -DCASE=0 -conformance A:IValue=3 -conformance B:IValue=7
//DIAGNOSTIC_TEST:SIMPLE(diag=REFERENCE):-target hlsl -entry computeMain -DCASE=1 -conformance A:IValue=3 -conformance B:IValue=7
//DIAGNOSTIC_TEST:SIMPLE(diag=ORDINARY):-target hlsl -entry computeMain -DCASE=2 -conformance A:IValue=3 -conformance B:IValue=7
//DIAGNOSTIC_TEST:SIMPLE(diag=METHOD_ARG):-target hlsl -entry computeMain -DCASE=3 -conformance A:IValue=3 -conformance B:IValue=7
//DIAGNOSTIC_TEST:SIMPLE(diag=EXPLICIT):-target hlsl -entry computeMain -DCASE=4 -conformance A:IValue=3 -conformance B:IValue=7
//DIAGNOSTIC_TEST:SIMPLE(diag=TWO_CALLS):-target hlsl -entry computeMain -DCASE=5 -conformance A:IValue=3 -conformance B:IValue=7
//DIAGNOSTIC_TEST:SIMPLE(diag=SHARED_TYPE):-target hlsl -entry computeMain -DCASE=6 -conformance A:IValue=3 -conformance B:IValue=7 -conformance Number<0>:ICodeScale=0 -conformance Number<1>:ICodeScale=1

// Slang 2025 disallows specializing a generic with an existential. The target
// parameter of `extension<T : IValue> T` is the exception because its set of types
// is specialized once per type; a method whose signature changes with T cannot be
// split that way, so it keeps the error, as does an ordinary generic function or an
// existential passed for a generic parameter of the method itself.
//
// METHOD_ARG calls `pair` through a generic wrapper, so its receiver is static and only
// the method's own parameter receives an existential. EXPLICIT passes an interface type
// explicitly for that parameter. TWO_CALLS shows that a method that cannot be split is
// reported once, at the first call. SHARED_TYPE uses conformers that are one IR type
// (empty specializations of one generic struct) and a method with two constraints: with
// a single type left, the witnesses of the two constraints cannot be paired per conformer.
#lang slang 2025

interface IValue { uint get(); [mutating] void bump(); }
struct A : IValue { uint v; uint get() { return 2; } [mutating] void bump() { v++; } }
struct B : IValue { uint v; uint get() { return 5; } [mutating] void bump() { v += 2; } }

extension<T : IValue> T
{
    T changingResult() { return this; }
    [mutating] void reference() { this.bump(); }
    uint pair<U : IValue>(U other) { return this.get() * 10 + other.get(); }
}

uint ordinary<T : IValue>(T value) { return value.get(); }

interface ICode { static uint code(); }
interface IScale { static uint scale(); }
interface ICodeScale : ICode, IScale {}
struct Number<let N : uint> : ICodeScale
{
    static uint code() { return N; }
    static uint scale() { return N + 1; }
}
extension<T : ICode & IScale> T
{
    uint codeOf() { return T.code() * T.scale(); }
}

uint pairWith<V : IValue>(V value, IValue other) { return value.pair(other); }
//METHOD_ARG:                                                       ^ cannot specialize generic with existential type
//METHOD_ARG:                                                       ^ specializing 'pair' with an existential type is not allowed. All generic arguments must be statically resolvable at compile time.

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
#elif CASE == 2
    outputBuffer[tid.x] = ordinary(a);
//ORDINARY:                       ^ cannot specialize generic with existential type
//ORDINARY:                       ^ specializing 'ordinary' with an existential type is not allowed. All generic arguments must be statically resolvable at compile time.
#elif CASE == 3
    outputBuffer[tid.x] = pairWith(A(), a);
#elif CASE == 4
    outputBuffer[tid.x] = a.pair<IValue>(A());
//EXPLICIT:                             ^ cannot specialize generic with existential type
//EXPLICIT:                             ^ specializing 'pair' with an existential type is not allowed. All generic arguments must be statically resolvable at compile time.
#elif CASE == 5
    outputBuffer[tid.x] = a.changingResult().get();
//TWO_CALLS:                              ^ cannot specialize generic with existential type
//TWO_CALLS:                              ^ specializing 'changingResult' with an existential type is not allowed. All generic arguments must be statically resolvable at compile time.
    outputBuffer[tid.y] = a.changingResult().get();
#else
    outputBuffer[tid.x] = createDynamicObject<ICodeScale>(tid.x, 0u).codeOf();
//SHARED_TYPE:                                                             ^ cannot specialize generic with existential type
//SHARED_TYPE:                                                             ^ specializing 'codeOf' with an existential type is not allowed. All generic arguments must be statically resolvable at compile time.
#endif
}
