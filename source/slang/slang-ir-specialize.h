// slang-ir-specialize.h
#pragma once

namespace Slang
{
struct IRModule;
struct IRInst;
struct IRFunc;
struct IRParam;
struct IRSpecialize;
struct SpecializationContext;
class DiagnosticSink;
class TargetProgram;

struct SpecializationOptions
{
    // Option that allows specializeModule to generate dynamic-dispatch code
    // wherever possible to open up more specialization opportunities.
    //
    bool lowerWitnessLookups = false;

    // Option to report dynamic dispatch sites.
    bool reportDynamicDispatchSites = false;
};

/// Specialize generic and interface-based code to use concrete types.
bool specializeModule(
    IRModule* module,
    TargetProgram* target,
    DiagnosticSink* sink,
    SpecializationOptions options);

void finalizeSpecialization(IRModule* module);

IRInst* specializeGeneric(
    SpecializationContext* context,
    IRSpecialize* specInst,
    bool queueFollowUpWork = true);
IRInst* specializeGeneric(IRSpecialize* specInst);

/// Run local specialization opportunities exposed under an already-materialized IR value.
bool specializeChildInsts(SpecializationContext* context, IRInst* rootInst);

/// Return the per-conformance type parameter that generic parameter `param` refers to: `param`
/// itself when it is the marked target `T` of `extension<T : I> T`, that `T` when `param` is the
/// witness for one of its constraints, or null for any other parameter.
IRParam* findPerConformanceTypeParam(IRParam* param);

/// Return whether `specialize` has at least one argument that is not yet a single static value
/// (a local value, or a set of possibilities from type-flow analysis), and binds every such
/// argument to one per-conformance type parameter or the witnesses of its constraints. This is
/// only a precondition for attempting one copy per type: the shared body is still used when the
/// method's signature changes with the type, when conformers that share one IR type meet more
/// than one constraint, or when a witness set is unbounded or empty.
bool isPerConformanceCandidate(IRSpecialize* specialize);

} // namespace Slang
