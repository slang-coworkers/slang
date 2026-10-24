# Per-conformance specialization of extension methods

A method of a generic extension whose target type is the extension's own type
parameter, `extension<T : I> T`, behaves like an interface method when it is called
on a dynamically selected value: the compiler specializes the whole method once per
concrete type and dispatches to the copy for the runtime type. This addresses the
helper-based requests in [#13268](https://github.com/shader-slang/slang/issues/13268)
and [#13267](https://github.com/shader-slang/slang/issues/13267) without another
interface, callback requirement, conformance registration, or attribute. Nothing in
the implementation is specific to geometry or RayQuery.

## Source contract

```slang
interface IA { uint a(); }
interface IB { uint b(); }
interface IValue : IA, IB {}

extension<T : IA & IB> T
{
    uint combine() { return this.a() * this.b(); }
}

// Given existing IValue conformance registrations:
// createDynamicObject<IValue>(typeID, payload).combine();
```

Each concrete copy of `combine` contains both interface calls and the computation
around them. Multiple constraints on `T` do not multiply the number of copies. The
method may have its own generic parameters, such as a traversal handler type or
`let Flags : uint` for `RayQuery<Flags>`, as long as their arguments are static.

Per-type copies apply in every language mode. Slang 2025 otherwise rejects
specializing a generic with an existential (E33180); a method of such an extension
is the exception when its copies can be formed.

A method gets per-type copies when its signature is the same for every concrete
type, apart from a by-value `this` or `T` payload: `void` or fixed results such as
`bool`, `float` and concrete structs, and concrete `out`/`inout` parameters. The
following shapes keep the shared body that ordinary set specialization builds (and
are still E33180 in Slang 2025):

- results or references whose type depends on `T`, such as a method returning `T`
  or a `[mutating]` method;
- nested payloads such as `Foo<T>`, and parameter packs whose expansion changes the
  signature;
- a second dynamic type, for example a method generic parameter that receives
  another existential;
- witnesses for constraints on something other than `T`.

In Slang 2025 the error for such a method is reported once, at the first call
that reaches its shared set specialization.

The compiler does not guarantee final driver instruction placement or faster
execution. Unknown conformance IDs keep the existing `createDynamicObject` contract.

## Representation and compiler boundary

`emitGenericDecl` (`slang-lower-to-ir.cpp`) marks the IR parameter for `T` with
`SpecializePerConformanceDecoration` when the generic's inner declaration is an
`ExtensionDecl` whose target type is that parameter. `emitGenericConstraintValue`
records a `ConstrainedTypeDecoration` naming `T` on each witness parameter for a
constraint on that marked `T`. For `T : IA & IB`, both witness parameters point to
`T`; equal possible-type sets or matching interface names alone cannot prove that.

A method with its own generic parameters lowers to a generic nested in the
extension's generic, so a call is `specialize(specialize(g, T', w'), N)`. When the
outer arguments bind the marked `T` dynamically in code outside a generic, the
specialization pass rewrites the call to `specialize(flattened(g), T', w', N)`, so
typeflow and the dispatcher see a generic that returns a function.
`flattenNestedGeneric` builds the flattened generic, which records `g` in a
`FlattenedGenericDecoration`. The flattened generic is only the dynamic call's
shape: each per-type copy is specialized through the nested form
`specialize(specialize(g, A, wA), N)`, and a specialization of the flattened
generic whose arguments all become static is rewritten back to that form. A copy
for `A` is therefore the same function a static call `a.method<N>()` produces, so
the method is not duplicated and its `static` variables are not split. Because
compiler-dictionary values are weak, the pass keeps the intermediate generic
`specialize(g, A, wA)` alive until it finishes, since the per-type copies are made
in a later round than the static calls.

Typeflow (`analyzeSpecialize`) supplies the set of types for `T` and a witness set
per constraint. `specializeGenericWithSetArgs` builds the ordinary signature with
one leading tag per witness set, then first calls
`trySpecializeHelperPerConformance`. That function requires every other argument
to be a single static value, indexes each witness set by `getConcreteType()`, and
checks that every set covers exactly the alternatives of the type set, with one
witness per type. It specializes the generic and its type once per type through
`specializeGeneric` and checks each resulting signature against the dispatcher.
No witness-entry positions, numeric-tag equality, structural equivalence relation,
or new substitution algorithm are used.

`createDispatchFunc` accepts the count of leading witness tags (one by default).
For this caller they all describe the same concrete `T`, so only the first selects a
branch. The remaining tags preserve the ordinary caller ABI but are not passed to
the concrete body. Existing `emitWitnessTableWrapper` handles direct by-value
payloads and fixed returns; identical concrete references pass through without
additional temporaries.

In Slang 2025, `addDecorationsForGenericsSpecializedWithExistentials` still marks
the call's specialization. Typeflow's `isInvalidExistentialSpecialization` accepts
a specialization whose dynamic arguments bind only the marked `T` and its witnesses
(`isPerConformanceSpecialization`), and `specializeCall` moves the mark, with the
call's location, to the set specialization. If `trySpecializeHelperPerConformance`
cannot form the copies for a marked set specialization,
`specializeGenericWithSetArgs` reports E33180.

## Relationship to #13245

The associated-result regression constructs and consumes a concrete associated
result within the method, avoiding an intermediate `AnyValue` in emitted HLSL.
That is distinct from returning a dynamically changing result across the method
boundary. Tag-namespace unification, arbitrary caller-tail duplication, and removal
of all existential conversions remain separate work.

## Tests

- `tests/language-feature/dynamic-dispatch/specialize-per-conformance*.slang`:
  CPU, Vulkan and D3D12 results plus HLSL, SPIR-V and DXIL structure checks for
  per-type copies, multiple constraints, fixed results, concrete references,
  associated results, separately compiled conformers, ray queries (also generic
  over the query flags) and methods with their own generic parameters.
- `tests/language-feature/dynamic-dispatch/interface-extension-diagnose.slang`:
  Slang 2025 accepts the extension method and still rejects an ordinary generic
  function called with the same existential.
- `tests/diagnostics/specialize-per-conformance-*.slang`: Slang 2025 keeps E33180
  for results and references whose type depends on `T` and for parameter packs;
  legacy mode compiles the shared body.
