########## the PC and condition codes registers #############
register fF { pc:64 = 0; }

register fD{
	Stat : 3 = STAT_AOK;
	icode : 4 = NOP;
	valC: 64 = 0;
	rA:4 = REG_NONE;
	rB:4 = REG_NONE;
	ifun:4 = 0;
}

register dE{
	icode:4 = NOP;
	ifun:4 = 0;
	rA:4 = REG_NONE;
	rB:4 = REG_NONE;
	valA:64 = 0;
	valB:64 = 0;
	valC:64 = 0;
	dstE:4 = REG_NONE;
	dstM:4 = REG_NONE;
	Stat:3 = STAT_AOK;
}

register eM{
	icode:4 = NOP;
	rA:4 = REG_NONE;
	rB:4 = REG_NONE;
	valA:64 = 0;
	valE:64 = 0;
	dstE:4 = REG_NONE;
	Stat:3 = STAT_AOK;
	conditionsMet : 1 = 0;
}

register mW {
	icode : 4 = NOP;
	valE : 64 = 0;
	valM : 64 = 0;
	dstE : 4 = REG_NONE;
	Stat : 3 = STAT_AOK;
}

register cC {
	SF:1 = 0;
	ZF:1 = 1;
}




########## Fetch #############
pc = F_pc;

f_icode = i10bytes[4..8];
f_ifun = i10bytes[0..4];
wire offset:64, valP:64;
offset = [
	f_icode in { HALT, NOP, RET } : 1;
	f_icode in { RRMOVQ, OPQ, PUSHQ, POPQ } : 2;
	f_icode in { JXX, CALL } : 9;
	1 : 10;
];
valP = F_pc + offset;

f_Stat = [
	f_icode == HALT : STAT_HLT;
	f_icode > 0xb : STAT_INS;
	1 : STAT_AOK;
];

f_rA = [
	f_icode == 0x2 : i10bytes[12..16];
	f_icode == 0x4 : i10bytes[12..16];
	f_icode == 0x5 : i10bytes[12..16];
	f_icode == 0x6 : i10bytes[12..16];
	f_icode == 0xA : i10bytes[12..16];
	f_icode == 0xB : i10bytes[12..16];
	1             : REG_NONE;
];

f_rB = [
	f_icode == 0x2 : i10bytes[8..12];
	f_icode == 0x3 : i10bytes[8..12];
	f_icode == 0x4 : i10bytes[8..12];
	f_icode == 0x5 : i10bytes[8..12];
	f_icode == 0x6 : i10bytes[8..12];
	f_icode == 0x8 : REG_RSP;
	f_icode == 0x9 : REG_RSP;
	f_icode == 0xA : REG_RSP;
	f_icode == 0xB : REG_RSP;
	1             : REG_NONE;
];

f_valC = [
	f_icode == IRMOVQ : i10bytes[16..80];
	f_icode == RMMOVQ : i10bytes[16..80];
	f_icode == MRMOVQ : i10bytes[16..80];
	f_icode == JXX : i10bytes[8..72];
	f_icode == CALL : i10bytes[8..72];
	1 : 0;
];

stall_F = (f_Stat != STAT_AOK);

########## Decode #############

reg_srcA = D_rA;

reg_srcB = D_rB;

d_dstE = [
	D_icode == 3 : D_rB;
	D_icode == 2 : D_rB;
	D_icode == 6 : d_rB;
	1 : REG_NONE;
];

d_dstM = [
	d_icode in {MRMOVQ}: d_rA;
	1:REG_NONE;
];

d_valA=[
	reg_srcA == REG_NONE : 0;
	reg_srcA == e_dstE : e_valE;
	reg_srcA == m_dstE : m_valE;
	reg_srcA == reg_dstE : reg_inputE;
	1: reg_outputA;
];

d_valB=[
	reg_srcB == REG_NONE : 0;
	reg_srcB == e_dstE : e_valE;
	reg_srcB == m_dstE : m_valE;
	reg_srcB == reg_dstE : reg_inputE;
	1:  reg_outputB;
];


d_Stat = D_Stat;
d_icode = D_icode;
d_valC = D_valC;
d_ifun = D_ifun;
d_rA = D_rA;
d_rB = D_rB;

########## Execute #############

e_valE = [
	e_icode in { IRMOVQ }: E_valC ;
	e_icode in { RRMOVQ,CMOVXX }: E_valA ;
	e_icode in { RMMOVQ, MRMOVQ }: E_valA ;
	e_icode == OPQ && E_ifun == ADDQ : E_valA + E_valB;
	e_icode == OPQ && E_ifun ==SUBQ	 : E_valB - E_valA;
       	e_icode == OPQ && E_ifun ==XORQ	 :E_valA ^ E_valB;
	e_icode == OPQ && E_ifun ==ANDQ	 : E_valA & E_valB;
	1:0;
];

c_ZF = (e_valE == 0);
c_SF = (e_valE >= 0x8000000000000000);
stall_C = (e_icode != OPQ);

e_conditionsMet = [
	E_ifun == 0x0 : 1;
	(E_ifun == 0x1 && (C_SF==1||C_ZF==1)): 1;
	(E_ifun == 0x2 && C_SF==1): 1;
	(E_ifun == 0x3 && C_ZF==1) : 1;
	(E_ifun == 0x4 && C_ZF==0): 1;
	(E_ifun == 0x5 && (C_SF==0||C_ZF==1)) : 1;
	(E_ifun == 0x6 && (C_SF==0&&C_ZF==0)): 1;
	1 : 0;
];

e_dstE=[
	!e_conditionsMet && e_icode == 0x2 : REG_NONE;
	e_icode == 0x3  ||  e_icode== 0x6 || e_icode == 0x2 : E_rB;
	e_icode == 0x5 : e_rA;
	e_icode == 0xA: REG_RSP;
	e_icode == 0xB : REG_RSP;
	e_icode == 0x8 : REG_RSP;
	e_icode == 0x9 : REG_RSP;
	1 : REG_NONE;
];


e_Stat = E_Stat;
e_icode = E_icode;
e_rA = E_rA;
e_rB = E_rB;
e_valA = E_valA;

########## Memory #############

mem_readbit = [
	m_icode == 0x5 :1;
	m_icode == 0xB :1;
	m_icode == 0x9 :1;
	1:0;
];
mem_writebit = [
	m_icode == 0x4 :1;
	m_icode == 0xA :1;
	m_icode == 0x8 :1;
	1:0;
];
mem_addr =[
	 m_icode== 0xB || m_icode== 0x9 : m_valE;
	 1: m_valE;
];
mem_input = [
	m_icode == 0x8: valP;
	1: M_valA;

];
	

m_Stat = M_Stat;
m_icode = M_icode;
m_dstE = M_dstE;
m_valE = M_valE;
m_valM = mem_output;

########## Writeback #############

reg_dstE = [
	W_icode in {IRMOVQ, RRMOVQ, OPQ, CMOVXX} : W_dstE;
	1 : REG_NONE;
];

reg_inputE = [
	W_icode in {IRMOVQ, RRMOVQ, OPQ, CMOVXX} : W_valE;
        1: 0xBADBADBAD;
];

########## PC update ########
f_pc = valP;

########## Status update ########
Stat = W_Stat;




