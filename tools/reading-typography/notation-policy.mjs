// Reviewed mathematical aliases. Scoped to books so prose words and program
// identifiers are never inferred to be products merely from their length.
const products=words=>Object.fromEntries(words.split(/\s+/).filter(Boolean).map(word=>[word,[...word].join(' ')]));
export const notationAliases={
 'visual-group-theory':{
  ...products('ab ba sss sssss ss ssss aba bab abc bc qn mn hv xg rf xr fr frf hh rL Lr gg hgh hghg ghgh RB BR RBR RR xy RRBB LRRRR LRLR RL LR xa aaxa axaa rb br uH bxa ji xab xba pq qp pt rfr gH Hg aH ah bH gh bh Hb hg kn nm abH gxyg bb aa rH fH gK hk iI xM HK kk ap CK ck gP Kg gaH cH gZ ax ac bi ts uA'),
  Rg:'R_g',Rh:'R_h',RgRh:'R_g R_h',r2:'r^2',r2f:'r^2 f',Cn:'C_n',Cm:'C_m',Cnm:'C_{n m}',nZ:'n ℤ',kZ:'k ℤ',cos20:'cos 20',deg:'deg'
 },
 'measure-probability':{
  ...products('fg tX EY nI hX'),Lp:'L^p',L2:'L^2',X1A:'X 1_A',Xs:'X^s',sup:'sup',inf:'inf'
 },
 stochastic:{
  ...products('EX EN EB np EK ER SQ EV ES hU au nh XY ET uS dS rV tc'),
  Sn:'S_n',Xn:'X_n',hj:'h_j',Uj:'U_j',Bj:'B_j',VarN:'Var N',VarX:'Var X',EYi:'E Y_i',EXn:'E X_n',bn:'b_n',T0:'T_0',Ni:'N_i',WQ:'W_Q',gB:'g_B',gC:'g_C',LQ:'L_Q',pii:'p_{i i}',Mn:'M_n',Yi:'Y_i',MT:'M_T',Hk:'H_k',Fn:'F_n',Wn:'W_n',Xk:'X_k',Ck:'C_k',ulogu:'u log u',log2:'log 2',hb:'h_b',Di:'D_i',Xj:'X_j',ST:'S_T',dET:'d E T',VarT:'Var T',vET:'v E T',uSn:'u S_n',dSn:'d S_n',Rn:'R^n',EXi:'E X_i',S0:'S_0',rsVs:'r s V_s',Vt:'V_t'
 },
 weiss:{...products('dP nC MN NK qN wN'),logN:'log N',logE:'log E',logV:'log V',Nlog:'N log',xlog:'x log',qi:'q_i',Hmax:'H_{max}'},
 csapp:Object.fromEntries('B2U B2T T2U U2T TMin TMax Bias'.split(' ').map(x=>[x,x])),
 eopl:{}
};
export const uprightMathNames=new Set('min inf sup cos sin ln exp log max mod gcd sgn Sym det Aut lcm Ker Im Perm Orb Stab Gal Dic Var GL Re SF OF ZF CF EA base clk CPI CPE RPM AMAT CO CI CT elems stride VA VPN VPO PA PPN new old B2U B2T T2U U2T TMin TMax Bias limsup liminf deg'.split(' '));
