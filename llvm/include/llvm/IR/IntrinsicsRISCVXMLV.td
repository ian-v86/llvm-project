//===- IntrinsicsRISCVXMLV.td - MLV intrinsics --------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines all of the vendor intrinsics for RISC-V.
//
//===----------------------------------------------------------------------===//

let TargetPrefix = "riscv" in {

  // Vector exponential (mlv.vexp) - unmasked version
  // Input: (passthru, vector_in, vl)
  // Output: vector_out
  class RISCV_MLV_Vexp_Unary
        : DefaultAttrsIntrinsic<[llvm_anyvector_ty],
                                [LLVMMatchType<0>, LLVMMatchType<0>, llvm_anyint_ty],
                                [IntrNoMem]>,
          RISCVVIntrinsic {
    let VLOperand = 2;
  }

  // Vector exponential (mlv.vexp) - masked version
  // Input: (passthru, vector_in, mask, vl, policy)
  // Output: vector_out
  class RISCV_MLV_Vexp_Unary_Masked
        : DefaultAttrsIntrinsic<[llvm_anyvector_ty],
                                [LLVMMatchType<0>, LLVMMatchType<0>,
                                 LLVMScalarOrSameVectorWidth<0, llvm_i1_ty>,
                                 llvm_anyint_ty, LLVMMatchType<1>],
                                [ImmArg<ArgIndex<4>>, IntrNoMem]>,
          RISCVVIntrinsic {
    let VLOperand = 3;
  }

  // Multiclass for mlv.vexp intrinsics
  multiclass RISCV_MLV_Vexp {
    def "int_riscv_" # NAME : RISCV_MLV_Vexp_Unary;
    def "int_riscv_" # NAME # "_mask" : RISCV_MLV_Vexp_Unary_Masked;
  }

  // Instantiate the mlv.vexp intrinsics
  defm mlv_vexp : RISCV_MLV_Vexp;

} // TargetPrefix = "riscv"
