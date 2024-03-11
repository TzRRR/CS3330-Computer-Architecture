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
	dstM:4 = REG_NONE;
	Stat:3 = STAT_AOK;
	conditionsMet : 1 = 0;
}

register mW {
	icode : 4 = NOP;
	valE : 64 = 0;
	valM : 64 = 0;
	dstE : 4 = REG_NONE;
	dstM : 4 = REG_NONE;
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

f_rA = i10bytes[12..16];
f_rB = i10bytes[8..12];

f_valC = [
	f_icode == IRMOVQ : i10bytes[16..80];
	f_icode == RMMOVQ : i10bytes[16..80];
	f_icode == MRMOVQ : i10bytes[16..80];
	f_icode == JXX : i10bytes[8..72];
	f_icode == CALL : i10bytes[8..72];
	1 : 0;
];

stall_F = [
	f_Stat != STAT_AOK || loadUse : 1;
	1 : 0;
];


########## Decode #############

d_Stat = D_Stat;
d_icode = D_icode;
d_valC = D_valC;
d_ifun = D_ifun;
d_rA = D_rA;
d_rB = D_rB;

reg_srcA = [
	d_icode in {RRMOVQ, OPQ, CMOVXX, RMMOVQ} : d_rA;
	1 : REG_NONE;
];

reg_srcB = [
	d_icode in {RRMOVQ, OPQ, CMOVXX, RMMOVQ, MRMOVQ} : d_rB;
	1: REG_NONE;
];

d_dstE = [
	D_icode == 3 : D_rB;
	D_icode == 2 : D_rB;
	D_icode == 6 : D_rB;
	1 : REG_NONE;
];

d_dstM = [
	D_icode in {MRMOVQ}: d_rA;
	1:REG_NONE;
];

d_valA=[
	reg_srcA == REG_NONE : 0;
	reg_srcA == m_dstM : m_valM;
	reg_srcA == W_dstM : W_valM;
	1: reg_outputA;
];

d_valB=[
	reg_srcB == REG_NONE : 0;
	reg_srcB == m_dstM : m_valM;
	reg_srcB == W_dstM : W_valM;
	1:  reg_outputB;
];

wire loadUse:1;
loadUse = [
	(reg_srcA == E_dstM || reg_srcB == E_dstM) && E_dstM != REG_NONE: 1;
	1 : 0;
];

    
stall_D = loadUse;


########## Execute #############

e_Stat = E_Stat;
e_icode = E_icode;
e_rA = E_rA;
e_rB = E_rB;
e_valA = E_valA;
e_dstM = E_dstM;

e_valE = [
	e_icode == 0x3 : E_valC ;
	e_icode == 0x2 : E_valA ;
	e_icode == 0x4 : E_valB + E_valC;
	e_icode == 0x5 : E_valB + E_valC;
	e_icode == 0x6 && E_ifun == ADDQ : E_valA + E_valB;
	e_icode == 0x6 && E_ifun == SUBQ : E_valB - E_valA;
       	e_icode == 0x6 && E_ifun == XORQ : E_valA ^ E_valB;
	e_icode == 0x6 && E_ifun == ANDQ : E_valA & E_valB;
	e_icode == 0x8 : reg_outputB - 8;
	e_icode == 0x9 : reg_outputB + 8;
	e_icode == 0xA : reg_outputB - 8;
	e_icode == 0xB : reg_outputB + 8;
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

bubble_E = loadUse;


########## Memory #############

m_Stat = M_Stat;
m_icode = M_icode;
m_dstE = M_dstE;
m_dstM = M_dstM;
m_valE = M_valE;
m_valM = mem_output;

mem_readbit = [
	m_icode == 0x5 :1;
	m_icode == 0xB :1;
	m_icode == 0x9 :1;
	1:0;
];
mem_writebit = [
	M_icode == 0x4 :1;
	M_icode == 0xA :1;
	M_icode == 0x8 :1;
	1:0;
];
mem_addr =[
	M_icode == 0xB : M_valE;
	M_icode == 0x4 : M_valE;
	M_icode == 0x5 : M_valE;
	 1: 0;
];
mem_input = [
	m_icode == 0x8: valP;
	1: M_valA;

];
	

########## Writeback #############

reg_dstE = [
	W_icode in {IRMOVQ, RRMOVQ, OPQ, CMOVXX} : W_dstE;
	1 : REG_NONE;
];

reg_dstM = [
	W_icode in {MRMOVQ, POPQ} : W_dstM;
	1 : REG_NONE;
];

reg_inputE = [
	W_icode in {IRMOVQ, RRMOVQ, OPQ, CMOVXX} : W_valE;
        1: 0xBADBADBAD;
];

reg_inputM = [
	W_icode in {MRMOVQ} : W_valM;
        1: 0xBADBADBAD;
];


########## PC update ########
f_pc = valP;

########## Status update ########
Stat = W_Stat;




