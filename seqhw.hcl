# Tianze Ren, tr2bx, 03/15/2023
register pP{
	pc:64 = 0;
}

#Fetch


pc = P_pc;
wire opcode:8, icode:4;
opcode = i10bytes[0..8]; 
icode = opcode[4..8];


Stat = [
	icode == HALT : STAT_HLT;
	icode > 0xb   : STAT_INS;
	1             : STAT_AOK;
];

wire valP:64;

valP = [
	icode == 0x0 : P_pc + 1;
	icode == 0x1 : P_pc + 1;
	icode == 0x2 : P_pc + 2;
	icode == 0x3 : P_pc + 10;
	icode == 0x4 : P_pc + 10;
	icode == 0x5 : P_pc + 10;
	icode == 0x6 : P_pc + 2;
	icode == 0x7 : P_pc + 9;
	icode == 0x8 : P_pc + 9;
	icode == 0x9 : P_pc + 1;
	icode == 0xA : P_pc + 2;
	icode == 0xB : P_pc + 2;
	1            : P_pc + 1;
];
wire rA: 4, rB: 4;
rA = [
	icode == 0x2 : i10bytes[12..16];
	icode == 0x4 : i10bytes[12..16];
	icode == 0x5 : i10bytes[12..16];
	icode == 0x6 : i10bytes[12..16];
	icode == 0xA : i10bytes[12..16];
	icode == 0xB : i10bytes[12..16];
	1             : REG_NONE;
];

rB = [
	icode == 0x2 : i10bytes[8..12];
	icode == 0x3 : i10bytes[8..12];
	icode == 0x4 : i10bytes[8..12];
	icode == 0x5 : i10bytes[8..12];
	icode == 0x6 : i10bytes[8..12];
	icode == 0x8 : REG_RSP;
	icode == 0x9 : REG_RSP;
	icode == 0xA : REG_RSP;
	icode == 0xB : REG_RSP;
	1             : REG_NONE;
];


wire valC:64;
valC = [
	icode == IRMOVQ : i10bytes[16..80];
	icode == RMMOVQ : i10bytes[16..80];
	icode == MRMOVQ : i10bytes[16..80];
	icode == JXX : i10bytes[8..72];
	icode == CALL : i10bytes[8..72];
	1 : 0;
];

wire cc:4, fn:4;

cc = [
	icode == 0x2 : i10bytes[0..4];
	icode == 0x7 : i10bytes[0..4];
	1             : 0;
];

fn = [
	icode == 0x6 : i10bytes[0..4];
	1             : 0;
];


#Decode

reg_srcA = rA;

reg_srcB = rB;

#Execute
wire opA: 64, opB: 64, op: 4;
op = [
	fn == 0x0 : 0;
	fn == 0x1 : 1;
	fn == 0x2 : 2;
	fn == 0x3 : 3;
	1         : 0;
];

opA=[
    icode == 0x6 : reg_outputA;
    icode == 0x4 : valC;
    icode == 0x5 : valC;
    icode == 0x8 : -0x8;
    icode == 0x9 : 0x8;
    icode == 0xA : -0x8;
    icode == 0xB : 0x8;
    1             : 0;
];

opB = reg_outputB;

wire valE: 64;
valE = [
	op == 3 : opA ^ opB;
	op == 0 : opA + opB;
	op == 1 : opB - opA;
	op == 2 : opA & opB;
	1 : 0;
];

register cC {
	SF:1 = 0;
	ZF:1 = 1;
 }

c_ZF = (valE == 0);
c_SF = (valE >= 0x8000000000000000);
stall_C = (icode != OPQ);


wire conditionsMet: 1;
conditionsMet = [
	cc == 0x0 : 1;
	(cc == 0x1 && (C_SF==1||C_ZF==1)): 1;
	(cc == 0x2 && C_SF==1): 1;
	(cc == 0x3 && C_ZF==1) : 1;
	(cc == 0x4 && C_ZF==0): 1;
	(cc == 0x5 && (C_SF==0||C_ZF==1)) : 1;
	(cc == 0x6 && (C_SF==0&&C_ZF==0)): 1;
	1 : 0;
];


#Memory

mem_readbit= [
	icode == 0x5 : 1;
	icode == 0x9 : 1;
	icode == 0xB : 1;
	1         : 0;
];

mem_writebit= [
	icode == 0x4 : 1;
	icode == 0x8 : 1;
	icode == 0xA : 1;
	1 : 0;
];

mem_addr= [
	icode == 0x4 : valE;
	icode == 0x5 : valE;
	icode == 0x8 : valE;
	icode == 0x9 : opB;
	icode == 0xA : valE;
	icode == 0xB : opB;
	1 : 0;
];


mem_input= [
	icode == 0x4 : reg_outputA;
	icode == 0x8 : valP;
	icode == 0xA : reg_outputA;
	1 : 0;
];

#Write Back

reg_inputM = mem_output;

reg_inputE = [
	icode == 0x2 && conditionsMet == 1: reg_outputA;
	icode == 0x3 : valC;
	icode == 0x6 : valE;
	icode == 0x8 : valE;
	icode == 0x9 : valE;
	icode == 0xA : valE;
	icode == 0xB : valE;
	1 : 0;
];

reg_dstE = [
	icode == 0x2 && conditionsMet == 1: reg_srcB;
	icode == 0x3 : reg_srcB;
	icode == 0x6 : reg_srcB;
	icode == 0x8 : reg_srcB;
	icode == 0x9 : reg_srcB;
	icode == 0xA : reg_srcB;
	icode == 0xB : reg_srcB;
	1 : REG_NONE;
];


reg_dstM = [
	icode == MRMOVQ : reg_srcA;
	icode == POPQ : reg_srcA;
	1 : REG_NONE;
];


#Update pc

p_pc=[
	(icode == 0x7 && conditionsMet == 1): valC;
	icode == 0x8  : valC;
	icode == 0x9  : mem_output;
	1 : valP;
];
