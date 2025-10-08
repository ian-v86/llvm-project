//===-- RISCVInstrInfoXMLV.td - MLV instructions -------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the vendor extensions defined by MLV.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// MLV extension instructions.
//===----------------------------------------------------------------------===//

// Base instruction definition for mlv.vexp
// Using a placeholder encoding (to be refined later)
class MLVInstVV<bits<6> funct6, RISCVVFormat opv, dag outs, dag ins,
                  string opcodestr, string argstr>
    : RVInst<outs, ins, opcodestr, argstr, [], InstFormatR> {
  bits<5> vs2;
  bits<5> vd;
  bit vm;

  let Inst{31-26} = funct6;
  let Inst{25} = vm;
  let Inst{24-20} = vs2;
  let Inst{19-15} = 0b00000; // vs1 unused for unary
  let Inst{14-12} = opv.Value;
  let Inst{11-7} = vd;
  let Inst{6-0} = 0b1010111; // OP-V

  let Uses = [VL, VTYPE];
  let RVVConstraint = NoConstraint;
}

// Base instruction for mlv.vexp (floating-point unary)
// Using temporary funct6 = 0b010000 (placeholder)
let Predicates = [HasVendorXMLV], mayLoad = 0, mayStore = 0, hasSideEffects = 0 in
def MLV_VEXP_V : MLVInstVV<0b010000, OPFVV, (outs VR:$vd),
                               (ins VR:$vs2, VMaskOp:$vm),
                               "mlv.vexp.v", "$vd, $vs2$vm">;

let Predicates = [HasVendorXMLV], mayLoad = 0, mayStore = 0, hasSideEffects = 0,
    DecoderNamespace = "XMLV" in {

// Pseudo instruction for mlv.vexp
// This is a placeholder pseudo that will be extended with proper encoding later
class MLVPseudoUnary<VReg vd_type, VReg vs_type, string opcodestr> :
      Pseudo<(outs vd_type:$vd),
             (ins vd_type:$passthru, vs_type:$vs2, AVL:$vl, sew:$sew, vec_policy:$policy),
             []>,
      RISCVVPseudo {
  let mayLoad = 0;
  let mayStore = 0;
  let hasSideEffects = 0;
  let Constraints = "$vd = $passthru";
  let HasVLOp = 1;
  let HasSEWOp = 1;
  let HasVecPolicyOp = 1;
  let BaseInstr = MLV_VEXP_V;
}

class MLVPseudoUnaryMask<VReg vd_type, VReg vs_type, string opcodestr> :
      Pseudo<(outs GetVRegNoV0<vd_type>.R:$vd),
             (ins GetVRegNoV0<vd_type>.R:$passthru, vs_type:$vs2,
                  VMaskOp:$vm, AVL:$vl, sew:$sew, vec_policy:$policy),
             []>,
      RISCVVPseudo {
  let mayLoad = 0;
  let mayStore = 0;
  let hasSideEffects = 0;
  let Constraints = "$vd = $passthru";
  let HasVLOp = 1;
  let HasSEWOp = 1;
  let HasVecPolicyOp = 1;
  let UsesMaskPolicy = 1;
  let IncludeInInversePseudoTable = 0;
  let BaseInstr = MLV_VEXP_V;
}

} // Predicates = [HasVendorXMLV]

// Instantiate the pseudos for all LMUL values
multiclass MLVPseudoVEXP_V {
  foreach m = MxList in {
    let VLMul = m.value in {
      def _V_#m.MX : MLVPseudoUnary<m.vrclass, m.vrclass, "mlv.vexp.v">,
                     RISCVMaskedPseudo<MaskIdx=2>,
                     Sched<[]>;
      def _V_#m.MX#_MASK : MLVPseudoUnaryMask<m.vrclass, m.vrclass, "mlv.vexp.v">,
                           RISCVMaskedPseudo<MaskIdx=2>,
                           Sched<[]>;
    }
  }
}

defm PseudoMLV_VEXP : MLVPseudoVEXP_V;

//===----------------------------------------------------------------------===//
// Intrinsic patterns
//===----------------------------------------------------------------------===//

// Pattern matching helpers
class VPatMLVUnaryNoMask<string intrinsic_name,
                           string inst,
                           ValueType result_type,
                           ValueType op2_type,
                           int log2sew,
                           LMULInfo vlmul,
                           VReg result_reg_class,
                           VReg op2_reg_class> :
  Pat<(result_type (!cast<Intrinsic>(intrinsic_name)
                   (result_type result_reg_class:$passthru),
                   (op2_type op2_reg_class:$rs2),
                   VLOpFrag)),
                   (!cast<Instruction>(inst#"_V_"#vlmul.MX)
                   (result_type result_reg_class:$passthru),
                   (op2_type op2_reg_class:$rs2),
                   GPR:$vl, log2sew, TU_MU)>;

class VPatMLVUnaryMask<string intrinsic_name,
                         string inst,
                         ValueType result_type,
                         ValueType op2_type,
                         ValueType mask_type,
                         int log2sew,
                         LMULInfo vlmul,
                         VReg result_reg_class,
                         VReg op2_reg_class> :
  Pat<(result_type (!cast<Intrinsic>(intrinsic_name#"_mask")
                   (result_type result_reg_class:$passthru),
                   (op2_type op2_reg_class:$rs2),
                   (mask_type V0),
                   VLOpFrag, (XLenVT timm:$policy))),
                   (!cast<Instruction>(inst#"_V_"#vlmul.MX#"_MASK")
                   (result_type result_reg_class:$passthru),
                   (op2_type op2_reg_class:$rs2),
                   (mask_type V0), GPR:$vl, log2sew, (XLenVT timm:$policy))>;

// Multiclass for generating patterns for all floating-point vector types
multiclass VPatMLVVEXP_V<string intrinsic> {
  foreach vti = AllFloatVectors in {
    let Predicates = !listconcat([HasVendorXMLV],
                                 GetVTypePredicates<vti>.Predicates) in {
      def : VPatMLVUnaryNoMask<intrinsic, "PseudoMLV_VEXP",
                                 vti.Vector, vti.Vector, vti.Log2SEW,
                                 vti.LMul, vti.RegClass, vti.RegClass>;
      def : VPatMLVUnaryMask<intrinsic, "PseudoMLV_VEXP",
                               vti.Vector, vti.Vector, vti.Mask, vti.Log2SEW,
                               vti.LMul, vti.RegClass, vti.RegClass>;
    }
  }
}

// Instantiate patterns for mlv.vexp intrinsic
defm : VPatMLVVEXP_V<"int_riscv_mlv_vexp">;
