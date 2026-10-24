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

/// Return the type parameter marked for per-conformance specialization that generic parameter
/// `param` belongs to: `param` itself when it is the target `T` of `extension<T : I> T`, that `T`
/// when `param` is a witness for one of its constraints, or null otherwise.
IRParam* findPerConformanceTypeParam(IRParam* param);

/// Return whether `specialize` binds runtime arguments (local values, or sets of possibilities
/// from type-flow analysis) only to one per-conformance type parameter and the witnesses
/// constraining it. Such a specialization is resolved by one concrete specialization per type
/// rather than by a shared body.
bool isPerConformanceCandidate(IRSpecialize* specialize);

} // namespace Slang
