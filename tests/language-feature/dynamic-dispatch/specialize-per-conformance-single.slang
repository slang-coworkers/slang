//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-cpu -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -shaderobj -output-using-type
interface IValue { uint get(); }
struct A : IValue { uint value; uint get() { return value; } }
extension<T : IValue> T
{
    uint count<let Step : uint>() { static uint counter = 0; counter += Step; return counter; }
    uint plain() { static uint c2 = 0; c2 += 1; return c2; }
}
//TEST_INPUT: type_conformance A:IValue = 3
//TEST_INPUT:ubuffer(data=[3], stride=4):name=ids
//TEST_INPUT:ubuffer(data=[0 0 0 0], stride=4):out,name=outputBuffer
StructuredBuffer<uint> ids;
RWStructuredBuffer<uint> outputBuffer;
[shader("compute")]
[numthreads(1, 1, 1)]
void computeMain(uint3 tid : SV_DispatchThreadID)
{
    let value = createDynamicObject<IValue>(ids[tid.x], 5u);
    A a = { 1 };
    outputBuffer[0] = value.count<3>();
    outputBuffer[1] = a.count<3>();
    outputBuffer[2] = value.plain();
    outputBuffer[3] = a.plain();
}
// CHECK: 3
// CHECK: 6
// CHECK: 1
// CHECK: 2
