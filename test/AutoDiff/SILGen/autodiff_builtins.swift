// RUN: %target-swift-frontend -parse-stdlib -emit-silgen %s | %FileCheck %s

import _Differentiation
import Swift

@_silgen_name("f_direct_arity1")
func f_direct_arity1(_ x: Float) -> Float {
  x
}

@_silgen_name("f_direct_arity1_jvp")
func f_direct_arity1_jvp(_ x: Float) -> (Float, (Float) -> Float) {
  (x, { $0 })
}

@_silgen_name("f_direct_arity1_vjp")
func f_direct_arity1_vjp(_ x: Float) -> (Float, (Float) -> Float) {
  (x, { $0 })
}

@_silgen_name("f_direct_arity2")
func f_direct_arity2(_ x: Float, _ y: Float) -> Float {
  x
}

@_silgen_name("f_indirect_arity1")
func f_indirect_arity1<T: AdditiveArithmetic & Differentiable>(_ x: T) -> T {
  x
}

// MARK: - applyDerivative

@_silgen_name("applyDerivative_f_direct_arity1_jvp")
func applyDerivative_f1_jvp(_ x: Float) -> (Float, (Float) -> Float) {
  return Builtin.applyDerivative_jvp(f_direct_arity1, x)
}
// CHECK-LABEL: sil{{.*}}@applyDerivative_f_direct_arity1_jvp
// CHECK: bb0([[X:%.*]] : $Float):
// CHECK: [[D:%.*]] = differentiable_function_extract [jvp]
// CHECK: [[D_RESULT:%.*]] = apply [[D]]([[X]])
// CHECK: ([[D_RESULT_0:%.*]], [[D_RESULT_1:%.*]]) = destructure_tuple [[D_RESULT]]
// CHECK: [[D_RESULT_RETUPLED:%.*]] = tuple ([[D_RESULT_0]] : {{.*}}, [[D_RESULT_1]] : {{.*}})
// CHECK: return [[D_RESULT_RETUPLED]]

@_silgen_name("applyDerivative_f_direct_arity1_vjp")
func applyDerivative_f1_vjp(_ x: Float) -> (Float, (Float) -> Float) {
  return Builtin.applyDerivative_vjp(f_direct_arity1, x)
}
// CHECK-LABEL: sil{{.*}}@applyDerivative_f_direct_arity1_vjp
// CHECK: bb0([[X:%.*]] : $Float):
// CHECK: [[D:%.*]] = differentiable_function_extract [vjp]
// CHECK: [[D_RESULT:%.*]] = apply [[D]]([[X]])
// CHECK: ([[D_RESULT_0:%.*]], [[D_RESULT_1:%.*]]) = destructure_tuple [[D_RESULT]]
// CHECK: [[D_RESULT_RETUPLED:%.*]] = tuple ([[D_RESULT_0]] : {{.*}}, [[D_RESULT_1]] : {{.*}})
// CHECK: return [[D_RESULT_RETUPLED]]

@_silgen_name("applyDerivative_f_direct_arity2_vjp")
func applyDerivative_f1_vjp(_ x: Float, _ y: Float) -> (Float, (Float) -> (Float, Float)) {
  return Builtin.applyDerivative_vjp_arity2(f_direct_arity2, x, y)
}
// CHECK-LABEL: sil{{.*}}@applyDerivative_f_direct_arity2_vjp
// CHECK: bb0([[X:%.*]] : $Float, [[Y:%.*]] : $Float):
// CHECK: [[D:%.*]] = differentiable_function_extract [vjp]
// CHECK: [[D_RESULT:%.*]] = apply [[D]]([[X]], [[Y]])
// CHECK: ([[D_RESULT_0:%.*]], [[D_RESULT_1:%.*]]) = destructure_tuple [[D_RESULT]]
// CHECK: [[D_RESULT_RETUPLED:%.*]] = tuple ([[D_RESULT_0]] : {{.*}}, [[D_RESULT_1]] : {{.*}})
// CHECK: return [[D_RESULT_RETUPLED]]

@_silgen_name("applyDerivative_f_indirect_arity1_vjp")
func applyDerivative_f1_vjp<T: AdditiveArithmetic & Differentiable>(t0: T) -> (T, (T.TangentVector) -> T.TangentVector) {
  return Builtin.applyDerivative_vjp(f_indirect_arity1, t0)
}
// CHECK-LABEL: sil{{.*}}@applyDerivative_f_indirect_arity1_vjp
// CHECK: bb0([[ORIG_RESULT_OUT_PARAM:%.*]] : $*T, [[X:%.]] : $*T):
// CHECK: [[D:%.*]] = differentiable_function_extract [vjp]
// CHECK: [[D_RESULT_BUFFER:%.*]] = alloc_stack $(T, @callee_guaranteed @substituted <τ_0_0, τ_0_1> (@in_guaranteed τ_0_0) -> @out τ_0_1 for <T.TangentVector, T.TangentVector>)
// CHECK: [[D_RESULT_BUFFER_0_FOR_STORE:%.*]] = tuple_element_addr [[D_RESULT_BUFFER]] : ${{.*}}, 0
// CHECK: [[D_RESULT:%.*]] = apply [[D]]([[D_RESULT_BUFFER_0_FOR_STORE]], [[X]])
// CHECK: [[D_RESULT_BUFFER_1_FOR_STORE:%.*]] = tuple_element_addr [[D_RESULT_BUFFER]] : ${{.*}}, 1
// CHECK: store [[D_RESULT]] to [init] [[D_RESULT_BUFFER_1_FOR_STORE]]
// CHECK: [[D_RESULT_BUFFER_0_FOR_LOAD:%.*]] = tuple_element_addr [[D_RESULT_BUFFER]] : ${{.*}}, 0
// CHECK: [[D_RESULT_BUFFER_1_FOR_LOAD:%.*]] = tuple_element_addr [[D_RESULT_BUFFER]] : ${{.*}}, 1
// CHECK: [[PULLBACK:%.*]] = load [take] [[D_RESULT_BUFFER_1_FOR_LOAD]]
// CHECK: copy_addr [take] [[D_RESULT_BUFFER_0_FOR_LOAD]] to [initialization] [[ORIG_RESULT_OUT_PARAM]]
// CHECK: return [[PULLBACK]]

struct ExamplePullbackStruct<T: Differentiable> {
  var pb0: (T.TangentVector) -> T.TangentVector
}

@_silgen_name("test_context_builtins")
func test_context_builtins() {
  let pbStruct = ExamplePullbackStruct<Float>(pb0: { $0 })
  let context = Builtin.autoDiffCreateLinearMapContext(Builtin.sizeof(type(of: pbStruct)))
  let topLevelSubctxAddr = Builtin.autoDiffProjectTopLevelSubcontext(context)
  UnsafeMutableRawPointer(topLevelSubctxAddr).storeBytes(of: pbStruct, as: type(of: pbStruct))
  let newBuffer = Builtin.autoDiffAllocateSubcontext(context, Builtin.sizeof(type(of: pbStruct)))
  UnsafeMutableRawPointer(newBuffer).storeBytes(of: pbStruct, as: type(of: pbStruct))
}

// CHECK-LABEL: sil{{.*}}@test_context_builtins
// CHECK: bb0:
// CHECK:   [[CTX:%.*]] = builtin "autoDiffCreateLinearMapContext"({{%.*}} : $Builtin.Word) : $Builtin.NativeObject
// CHECK:   [[BORROWED_CTX:%.*]] = begin_borrow [lexical] [[CTX]] : $Builtin.NativeObject
// CHECK:   [[BUF:%.*]] = builtin "autoDiffProjectTopLevelSubcontext"([[BORROWED_CTX]] : $Builtin.NativeObject) : $Builtin.RawPointer
// CHECK:   [[BUF:%.*]] = builtin "autoDiffAllocateSubcontext"([[BORROWED_CTX]] : $Builtin.NativeObject, {{.*}} : $Builtin.Word) : $Builtin.RawPointer
// CHECK:   destroy_value [[CTX]]
