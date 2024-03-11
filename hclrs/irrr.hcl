# Tianze Ren, tr2bx, 02/27/2023
register pP{
	pc:64 = 0;
}
pc = P_pc;
wire opcode:8, icode:4;
opcode = i10bytes[0..8]; 
icode = opcode[4..8];  

#rrmovq
reg_srcA = i10bytes[12..16];
reg_srcB = i10bytes[8..12];

wire valC:64;
valC = [
	icode == IRMOVQ : i10bytes[16..80];
	icode == JXX : i10bytes[8..72];
	1 : 0;
];

reg_inputE = [
	icode == IRMOVQ : valC;
	icode == RRMOVQ : reg_outputA;
	1 : 0;
];

reg_dstE = [
	icode == IRMOVQ : reg_srcB;
	icode == RRMOVQ : reg_srcB;
	1 : REG_NONE;
];




Stat = [
	icode == HALT : STAT_HLT;
	icode > 0xb   : STAT_INS;
	1             : STAT_AOK;
];

p_pc = [
	icode == HALT : P_pc + 1;
	icode == NOP  : P_pc + 1;
	icode == RRMOVQ : P_pc + 2;
	icode == IRMOVQ : P_pc + 10;
	icode == RMMOVQ : P_pc + 10;
	icode == MRMOVQ : P_pc + 10;
	icode == OPQ  : P_pc + 2;
	icode == CMOVXX : P_pc + 2;
	icode == CALL : P_pc + 9;
	icode == RET  : P_pc + 1;
	icode == PUSHQ : P_pc + 2;
	icode == POPQ : P_pc + 2;
	icode == JXX : valC;
	1	      : 0;
];
