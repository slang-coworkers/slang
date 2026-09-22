// Test for issue #13140: when member lookup fails on a value (or the type) of a
// generic type parameter, the compiler suggests a user-declared interface the
// parameter could be constrained to, as a follow-on note to the "member not
// found" error (e.g. `where Vertex : IHasNormal`).
//
// The suggestion is deliberately conservative (best-effort advice): only
// user-declared, non-generic interfaces are offered, and only when the interface
// declares a member usable in the access that failed (a static access `T.m`
// requires a static requirement).
//
// This runs in exhaustive mode: every emitted diagnostic must be annotated, so
// the negative cases below are enforced automatically — a spurious suggestion
// note would be an unannotated diagnostic and fail the test.

//DIAGNOSTIC_TEST:SIMPLE(diag=CHECK):-target spirv

interface IHasNormal
{
    float3 getNormal();
}

interface IContainer<T>
{
    T getItem();
}

interface IFactory
{
    static int make();
}

interface IHasDoThing
{
    int doThing();
}

interface IBase
{
    int baseThing();
}

interface IDerived : IBase
{
}

// Positive: a value member access on an unconstrained generic parameter suggests
// the user-declared interface that declares the member.
float3 valueMember<Vertex>(Vertex v)
{
    return v.getNormal();
//CHECK:     ^^^^^^^^^ member not found
//CHECK:     ^^^^^^^^^ 'getNormal' is not a member of 'Vertex'.
//CHECK:     ^^^^^^^^^ consider adding a constraint such as 'where Vertex : IHasNormal', since 'getNormal' is declared by that interface
}

// Positive: a static member access on the type parameter itself suggests an
// interface whose matching requirement is static.
int staticMember<T>()
{
    return T.make();
//CHECK:     ^^^^ member not found
//CHECK:     ^^^^ 'make' is not a member of 'typeof(T)'.
//CHECK:     ^^^^ consider adding a constraint such as 'where T : IFactory', since 'make' is declared by that interface
}

// Positive: only the interface that *directly* declares the member is suggested; a derived
// interface that merely inherits it is not, because the search does not walk the inheritance graph.
int inheritedMemberDirectOnly<T>(T t)
{
    return t.baseThing();
//CHECK:     ^^^^^^^^^ member not found
//CHECK:     ^^^^^^^^^ 'baseThing' is not a member of 'T'.
//CHECK:     ^^^^^^^^^ consider adding a constraint such as 'where T : IBase', since 'baseThing' is declared by that interface
}

// Negative: only a *generic* interface declares the member. A bare
// `where C : IContainer` is not a valid constraint, so no suggestion is offered.
int genericInterfaceNotSuggested<C>(C c)
{
    return c.getItem();
//CHECK:     ^^^^^^^ member not found
//CHECK:     ^^^^^^^ 'getItem' is not a member of 'C'.
}

// Negative: the access is static (`U.doThing()`) but the only interface declaring
// `doThing` declares it as an instance requirement, so constraining `U` to it
// would not make the static access valid — no suggestion is offered.
int staticInstanceMismatch<U>()
{
    return U.doThing();
//CHECK:     ^^^^^^^ member not found
//CHECK:     ^^^^^^^ 'doThing' is not a member of 'typeof(U)'.
}

// Negative: no interface declares the failed name, so no suggestion is offered.
float noSuggestion<Vertex>(Vertex v)
{
    return v.noSuchMember();
//CHECK:     ^^^^^^^^^^^^ member not found
//CHECK:     ^^^^^^^^^^^^ 'noSuchMember' is not a member of 'Vertex'.
}

// Negative: the base is a concrete (non-generic) type, so even though 'getNormal'
// matches an interface, no constraint suggestion is offered.
struct Concrete {}
float3 concreteBase(Concrete c)
{
    return c.getNormal();
//CHECK:     ^^^^^^^^^ member not found
//CHECK:     ^^^^^^^^^ 'getNormal' is not a member of 'Concrete'.
}
