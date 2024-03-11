# Tianze Ren, tr2bx, 03/31/2023
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
	1             : REG_NONE;
];

rB = [
	icode == 0x2 : i10bytes[8..12];
	icode == 0x3 : i10bytes[8..12];
	icode == 0x4 : i10bytes[8..12];
	icode == 0x5 : i10bytes[8..12];
	icode == 0x6 : i10bytes[8..12];
	1             : REG_NONE;
];


wire valC:64;
valC = [
	icode == IRMOVQ : i10bytes[16..80];
	icode == RMMOVQ : i10bytes[16..80];
	icode == RMMOVQ : i10bytes[16..80];
	icode == JXX : i10bytes[8..72];
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
wire opA: 64, opB: 64;
opA=[
    icode == 0x6 : reg_outputA;
    icode == 0x4 : valC;
    icode == 0x5 : valC;
    1             : 0;
];

opB = reg_outputB;

wire valE: 64;
valE = [
	icode == OPQ && fn == 3 : opA ^ opB;
	icode == OPQ && fn == 0 : opA + opB;
	icode == OPQ && fn == 1 : opB - opA;
	icode == OPQ && fn == 2 : opA & opB;
	icode == RMMOVQ : opB + opA;
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
	cc == 0 : 1;
	cc == 1 : C_SF || C_ZF;
	cc == 2 : C_SF;
	cc == 3 : C_ZF;
	cc == 4 : !C_ZF;
	cc == 5 : !C_SF || C_ZF;
	cc == 6 : !C_SF && !C_ZF;
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
	1 : 0;
];

mem_addr= [
	icode == 0x4 : valE;
	icode == 0x5 : valE;
	1 : 0;
];
mem_input= [
	icode == 0x4 : reg_outputA;
	1 : 0;
];

#Write Back

reg_inputE = [
	icode == IRMOVQ : valC;
	icode == CMOVXX && conditionsMet == 1 : reg_outputA;
	icode == OPQ : valE;
	1 : 0;
];

reg_dstE = [
	icode == IRMOVQ : reg_srcB;
	icode == CMOVXX && conditionsMet == 1 : reg_srcB;
	icode == OPQ : reg_srcB;
	1 : REG_NONE;
];


reg_dstM = [
	icode == 0x5 : reg_srcA;
	1 : REG_NONE;
];

reg_inputM = mem_output;

#Update pc

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
