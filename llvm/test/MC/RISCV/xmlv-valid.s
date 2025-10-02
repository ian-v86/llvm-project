# RUN: llvm-mc -triple=riscv64 -show-encoding --mattr=+v,+xmlv %s \
# RUN:        | FileCheck %s --check-prefixes=CHECK-ENCODING,CHECK-INST
# RUN: not llvm-mc -triple=riscv64 -show-encoding %s 2>&1 \
# RUN:        | FileCheck %s --check-prefix=CHECK-ERROR
# RUN: llvm-mc -triple=riscv64 -filetype=obj --mattr=+v,+xmlv %s \
# RUN:        | llvm-objdump -d --mattr=+v,+xmlv - \
# RUN:        | FileCheck %s --check-prefix=CHECK-INST
# RUN: llvm-mc -triple=riscv64 -filetype=obj --mattr=+v,+xmlv %s \
# RUN:        | llvm-objdump -d - | FileCheck %s --check-prefix=CHECK-UNKNOWN

# Vector exponential instruction - unmasked
mlv.vexp.v v8, v4
# CHECK-INST: mlv.vexp.v v8, v4
# CHECK-ENCODING: [0x57,0x14,0x40,0x42]
# CHECK-ERROR: instruction requires the following: 'XMLV' (MLV Vector Math Extensions){{$}}
# CHECK-UNKNOWN: 42401457 <unknown>

# Vector exponential instruction - masked
mlv.vexp.v v8, v4, v0.t
# CHECK-INST: mlv.vexp.v v8, v4, v0.t
# CHECK-ENCODING: [0x57,0x14,0x40,0x40]
# CHECK-ERROR: instruction requires the following: 'XMLV' (MLV Vector Math Extensions){{$}}
# CHECK-UNKNOWN: 40401457 <unknown>
