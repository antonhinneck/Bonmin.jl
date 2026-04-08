using Pkg
Pkg.activate(pwd())
using DSR
using PowerModels
using Ipopt
using JuMP
using Cycles
using Graphs
using PyPlot

## Solve Rural load
###################

cname1_base = "mv_comm0nosw_gen_full_base.m"
c1_base = PowerModels.parse_file(joinpath(joinpath(pwd(), "demo"), cname1_base))
g1_base, eid2lid1_base, lid2eid1_base = toGraph(c1_base)
is_connected(g1_base)
result1_base = solve_pf(c1_base, ACPPowerModel, Ipopt.Optimizer)
ref_base = PowerModels.build_ref(c1_base)[:it][:pm][:nw][PowerModels.nw_id_default]

_, max_vm_vio1_base, vio1_base, _, _, _, = analyse_voltage(Dict([i => result1_base["solution"]["bus"][string(i)]["vm"] for i in keys(ref_base[:bus])]), ref_base)

sl = 0.0
for l in c1_base["load"]
    sl += l[2]["pd"]
end
pl1_base = result1_base["solution"]["gen"]["1"]["pg"] - sl

cname1 = "mv_comm0nosw_gen_full.m"
c1 = PowerModels.parse_file(joinpath(joinpath(pwd(), "demo"), cname1))

g1, eid2lid1, lid2eid1 = toGraph(c1)
ref1 = PowerModels.build_ref(c1)[:it][:pm][:nw][PowerModels.nw_id_default]

ms = ones(ne(g1))
ms[1] = 0.0
ms[26] = 0.0
ms[102] = 0.0
ms[103] = 0.0
ms[104] = 0.0
ms[105] = 0.0
ms[107] = 0.0
ms[109] = 0.0

m_cdsr1, btz1, p_cdsr1, q_cdsr1 = solve_cdsr(c1, mip_start = ms, time_limit = 900)