//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-dx12 -compute -shaderobj -output-using-type
//TEST(compute):COMPARE_COMPUTE_EX(filecheck-buffer=CHECK):-vk -compute -shaderobj -output-using-type

// Deliberately compare the existing copy-in/copy-out behavior for aliased state
// arguments against the per-conformance extension method, without prescribing an
// alias ordering.
#pragma warning(disable:30051)

interface IValue
{
    uint get();
    [mutating] void increment();
}

struct A : IValue
{
    uint value;
    uint get() { return value; }
    [mutating] void increment() { value++; }
}

struct B : IValue
{
    uint value;
    uint get() { return value * 2; }
    [mutating] void increment() { value += 2; }
}

// This file checks results and the copy-in/copy-out behavior of aliased arguments. By
// design, the concrete return and the concrete references get per-type copies and the
// mutating method keeps the shared body (its `this` reference changes type);
// specialize-per-conformance-not-applied.slang checks the latter in Slang 2025.
extension<T : IValue> T
{
    uint returnValue() { return this.get(); }

    [mutating] void mutate() { this.increment(); }

    void aliasState(inout uint a, inout uint b)
    {
        a += this.get();
        b += a;
    }
}

void mutateValue<T : IValue>(T value, out uint result)
{
    var copy = value;
    copy.mutate();
    result = copy.get();
}

void ordinaryAliasState<T : IValue>(T value, inout uint a, inout uint b)
{
    a += value.get();
    b += a;
}

//TEST_INPUT: type_conformance A:IValue = 3
//TEST_INPUT: type_conformance B:IValue = 7
//TEST_INPUT:ubuffer(data=[3 7], stride=4):name=ids
//TEST_INPUT:ubuffer(data=[0 0 0 0 0 0], stride=4):out,name=outputBuffer
StructuredBuffer<uint> ids;
RWStructuredBuffer<uint> outputBuffer;

[shader("compute")]
[numthreads(2, 1, 1)]
void computeMain(uint3 tid : SV_DispatchThreadID)
{
    let value = createDynamicObject<IValue>(ids[tid.x], 5u);
    uint result = 0;
    uint offset = tid.x * 3;
    outputBuffer[offset] = value.returnValue();
    mutateValue(value, result);
    outputBuffer[offset + 1] = result;
    uint extensionResult = 1;
    uint ordinary = 1;
    value.aliasState(extensionResult, extensionResult);
    ordinaryAliasState(value, ordinary, ordinary);
    outputBuffer[offset + 2] = extensionResult == ordinary ? 1 : 0;
}

// CHECK: 5
// CHECK: 6
// CHECK: 1
// CHECK: 10
// CHECK: 14
// CHECK: 1
