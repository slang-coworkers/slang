//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cpu -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-dx12 -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -shaderobj -output-using-type
//TEST:SIMPLE(filecheck=HLSL):-target hlsl -entry computeMain -conformance A:IValue=7 -conformance B:IValue=3
//TEST:SIMPLE(filecheck=SPIRV):-target spirv -entry computeMain -conformance A:IValue=7 -conformance B:IValue=3

interface IA { uint a(); }
interface IB { uint b(); }
interface IValue : IA, IB {}
struct A : IValue { uint a() { return 2; } uint b() { return 3; } }
struct B : IValue { uint a() { return 5; } uint b() { return 7; } }

uint readMarker(inout uint state) { return state++; }

// IA and IB produce distinct witness sets and runtime tag namespaces. Both
// constrain T, so each concrete copy must select matching concrete witnesses.
extension<T : IA & IB> T
{
    uint combine(inout uint state) { return readMarker(state) + this.a() * this.b(); }
}

//TEST_INPUT: type_conformance A:IValue = 7
//TEST_INPUT: type_conformance B:IValue = 3
//TEST_INPUT:ubuffer(data=[7 3], stride=4):name=ids
//TEST_INPUT:ubuffer(data=[0 0 0 0], stride=4):out,name=outputBuffer
StructuredBuffer<uint> ids;
RWStructuredBuffer<uint> outputBuffer;
[shader("compute")]
[numthreads(2, 1, 1)]
void computeMain(uint3 tid : SV_DispatchThreadID)
{
    uint state = 10;
    outputBuffer[tid.x * 2] = createDynamicObject<IValue>(ids[tid.x], 0u).combine(state);
    outputBuffer[tid.x * 2 + 1] = state;
}
// CHECK: 16
// CHECK: 11
// CHECK: 45
// CHECK: 11
// HLSL: = readMarker
// HLSL: = readMarker
// SPIRV: OpEntryPoint GLCompute
