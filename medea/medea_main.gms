$title *medea* _ an economic model of the electricity system in Europe

$ontext
Abstract power system model *medea*, written by Sebastian Wehrle and Johannes Schmidt.
Data for concrete model instantiation is generated by the accompanying
python script instantiate.py

With additional, inserted model code, medea was used for:
* District heating systems under high CO2 prices: the role of the pass-through from emission cost to electricity prices:
  medea_dhpt.gms
* The cost of undistrubed landscapes:
  medea_udls.gms
* Austrian policy analysis:
  medea_pobu.gms

# TO-DO: scatter of conventional generation + psp pumping & turbining against
#        renewables max and peak load
#        to check assumptions in ancillary services equation (minimal generation)
#        - source for cost grid expansion
#        - source for cost of lost load

Full model code, data and licensing information provided at:
https://github.com/inwe-energy/medea

For comments, suggestions, bug reporting and other correspondence please write to
sebastian.wehrle@boku.ac.at
$offtext

$onEoLCom
$EoLCom #


********************************************************************************
********** set declaration
********************************************************************************
sets
         f                                       fuels
         l                                       limits to feasible operating region
         prd                                     products
         props                                   technical properties of hydro storage plants
         r                                       regions
         tec                                     power plant technologies
         tec_chp(tec)                            subset of CHP technologies
         tec_pth(tec)                            subset of power to heat technologies
         tec_strg                                 hydro storage technologies
         tec_itm                                 renewable generation technologies
         t                                       time - hours
         start_t(t)                              hour for initial values
         end_t(t)                                end time of iteration
;

alias(r,rr);

********************************************************************************
********** parameter declaration
********************************************************************************
parameters
         ANCIL_SERVICE_LVL(r)                    generation level required for provision of ancillary services
         CONSUMPTION(r,t,prd)                    hourly consumption of power and heat [GW]
         EFFICIENCY(tec,prd,f)                   electrical efficiency of power plant [%]
         EMISSION_INTENSITY(f)                   specific emission factor of each fuel [kt CO2 per GWh fuel]
         FEASIBLE_INPUT(tec,l,f)                 fuel requirement for feasible output generation []
         FEASIBLE_OUTPUT(tec,l,prd)              feasible combinations of outputs []
         GEN_PROFILE(r,t,tec_itm)                generation profile of intermittent technologies
         FLOW_EXPORT(r,t)                        exports to regions not modelled [GW]
         FLOW_IMPORT(r,t)                        imports from regions not modelled [GW]
         INSTALLED_CAP_ITM(r,tec_itm)            installed intermittent capacities [GW]
         INSTALLED_CAP_THERM(r,tec)              installed thermal capacities [GW]
         INVESTCOST_ITM(r,tec_itm)               annuity of investment in 1 GW intermittent technology
         INVESTCOST_THERMAL(tec)                 annuity of investment in 1 GW thermal generation technology
         MAX_EMISSIONS(r)                        upper emission limit
         ATC(r,rr)                               net transfer capacity from region r to region rr
         NUM(r,tec)                              number of installed 100 MW capacity slices of each technology
         OM_FIXED_COST(tec)                      quasifixed cost of operation & maintenance
         OM_VARIABLE_COST(tec)                   variable cost of operation & maintenance
         PRICE_DA(t,r)                           observed electricity price on day-ahead market [k EUR per GWh]
         PRICE_EUA(t,r)                          price of emission allowances [k EUR per kt CO2]
         PRICE_FUEL(t,r,f)                       price of fuel [k EUR per GWh]
         RESERVOIR_INFLOWS(r,t,tec_strg)         inflows to reservoirs of hydro storage plants [GW]
         STORAGE_PROPERTIES(r,tec_strg,props)    technical properties of electricity storages
         SWITCH_INVEST_THERM                     switch for investment in thermal units
         SWITCH_INVEST_ITM(r,tec_itm)            switch for investment in intermittents
         SWITCH_INVEST_STORAGE(r, tec_strg)      switch for investment in storage technologies
         SWITCH_INVEST_ATC(r,rr)                 switch for investment in interconnectors
;
* starting and ending values (mostly for intra-year iterations)
parameters
         FINAL_STORAGE(r,t,tec_strg)              final reservoir filling level
         INIT_GEN(r,t,tec,prd)                    initial generation at iteration start
         INIT_PUMP(r,t,tec_strg)                  initial pumping level
         INIT_STORAGE(r,t,tec_strg)               initial reservoir filling level
         INIT_TURB(r,t,tec_strg)                  initial generation of hydro storage plant at iteration start
;
********************************************************************************
********** data instantiation
********************************************************************************
$if NOT exist MEDEA_%scenario%_data.gdx  $gdxin medea_main_data
$if     exist MEDEA_%scenario%_data.gdx  $gdxin medea_%scenario%_data
$load  f l t tec tec_chp tec_strg tec_itm tec_pth prd props r
$load  ANCIL_SERVICE_LVL CONSUMPTION EMISSION_INTENSITY FLOW_EXPORT EFFICIENCY
$load  FEASIBLE_INPUT FEASIBLE_OUTPUT GEN_PROFILE STORAGE_PROPERTIES FLOW_IMPORT
$load  INSTALLED_CAP_ITM INSTALLED_CAP_THERM INVESTCOST_ITM INVESTCOST_THERMAL
$load  ATC NUM OM_FIXED_COST OM_VARIABLE_COST PRICE_DA PRICE_EUA
$load  PRICE_FUEL RESERVOIR_INFLOWS SWITCH_INVEST_THERM SWITCH_INVEST_ITM
$load  SWITCH_INVEST_STORAGE SWITCH_INVEST_ATC
$gdxin

********************************************************************************
********** helper parameters
********************************************************************************
parameters
PEAK_LOAD(r),
PEAK_PROFILE(r,tec_itm);

PEAK_LOAD(r) = smax(t, CONSUMPTION(r,t,'power'));
PEAK_PROFILE(r,tec_itm) = smax(t, GEN_PROFILE(r,t,tec_itm) );

display PEAK_LOAD, PEAK_PROFILE;

********************************************************************************
********** variable declaration
********************************************************************************
variables
         syscost                                 total system cost (to be minimized)
         cost(r)                                 total cost per region
         emissions(r)                            total emissions from power generation
         flow(r,rr,t)                            electricity flow from r to rr (i.e. export if positive) [GW]
;
positive variables
         cc_weights(r,t,tec,l)                   weights of co-generation convex combination
         cost_emission(r,t,tec)                  emission cost
         cost_fuel(r,t,tec)                      fuel cost
         cost_om(r,tec)                          operation & maintenance cost
         cost_invgen(r)                          cost of investment in generators
         cost_invstrg(r)                         cost of investment in storages
         cost_gridexpansion(r)                   cost of transmission grid expansion
         decommission(r,tec)                     plant decommissioning
         invest_res(r,tec_itm)                   added capacity of intermittent technologies
         invest_thermal(r,tec)                   thermal power plant investment
         invest_storage_power(r,tec_strg)        invested storage power (charge - discharge)
         invest_storage_energy(r,tec_strg)       invested storage energy
         q_curtail(r,t)                          unused renewable generation
         q_fueluse(r,t,tec,f)                    fuel consumed
         q_gen(r,t,tec,prd)                      energy generation
         q_nonserved(r,t,prd)                    consumption for which there is no supply
         q_store_in(r,t,tec_strg)                 electricity stored
         q_store_out(r,t,tec_strg)                electricity generated from storages
         storage_level(r,t,tec_strg)              energy stored in storages
         invest_atc(r,rr)                        investment in transmission capacity
;

********************************************************************************
******* equation declaration
********************************************************************************
equations
         objective                               total system cost calculation
         obj_costreg                             calculation of cost per region
         obj_fuelcost                            total fuel cost
         obj_emissioncost                        total emission cost
         obj_omcost                              total O&M cost
         obj_invgencost                          total cost of investment in generators
         obj_invstoragecost(r)                   total cost of storage investment
         obj_gridcost                            total cost of transmission grid expansion
         SD_balance_el                           supply-demand balance electricity
         SD_balance_ht                           supply-demand balance heat
         caplim_generation                       capacity limit on thermal generators
         nonchp_generation                       fuel requirement of non-CHPs
         pth_generation                          fuel requirement of power to heat units
         cc_a                                    CHP fuel-output combination must be convex
         cc_b                                    feasible output combinations of CHPs
         cc_c                                    feasible fuel requirement of CHPs
         storelim_out                            generation limit of storages
         storelim_in                             charging limit of storages
         storelim_storage                        energy limit of hydro storages
         storage_balance                         electricity balance of storages
         storage_sizing                          size energy storage to store at least one hour
         emission_calculation                    total CO2 emissions from fuel combustion
         decommission_limit                      only active plants can be decommissioned
         ancillary_service                       must-run for provision of ancillary services
         curtail_limit                           only generation from intermittent sources can be curtailed
         flow_balance                            imports are exports from elsewhere
         flow_constraint_a                       capacity restriction on exports
         flow_constraint_b                       capacity restriction on imports
         atc_invest_symmetry                     atc investment increases capacity in both directions
;

********************************************************************************
******* model equations
* ------------------------------------------------------------------------------
* OBJECTIVES
* ------------------------------------------------------------------------------
objective..                      syscost
                                 =E=
                                 sum(r, cost(r))
                                 ;
obj_costreg(r)..                 cost(r)
                                 =E=
                                 sum((t,tec), cost_fuel(r,t,tec))
                                 + sum((t,tec), cost_emission(r,t,tec))
                                 + sum(tec, cost_om(r,tec))
                                 + cost_invgen(r)
                                 + cost_invstrg(r)
                                 + 12500 * sum((t,prd), q_nonserved(r,t,prd))
                                 + 2000 * cost_gridexpansion(r)
                                 ;
obj_fuelcost(r,t,tec)..          cost_fuel(r,t,tec)
                                 =E=
                                 sum(f, PRICE_FUEL(t,r,f) * q_fueluse(r,t,tec,f))
                                 ;
obj_emissioncost(r,t,tec)..      cost_emission(r,t,tec)
                                 =E=
                                 sum(f, PRICE_EUA(t,r) * EMISSION_INTENSITY(f) * q_fueluse(r,t,tec,f))
                                 ;
obj_omcost(r,tec)..              cost_om(r,tec)
                                 =E=
                                 OM_FIXED_COST(tec) * (NUM(r,tec) - decommission(r,tec) + invest_thermal(r,tec))
                                 + sum((t,prd), OM_VARIABLE_COST(tec) * q_gen(r,t,tec,prd))
                                 ;
obj_invgencost(r)..              cost_invgen(r)
                                 =E=
                                 sum(tec, INVESTCOST_THERMAL(tec) * invest_thermal(r,tec))
                                 + sum(tec_itm, INVESTCOST_ITM(r,tec_itm) * invest_res(r,tec_itm))
                                 ;
obj_invstoragecost(r)..          cost_invstrg(r)
                                 =E=
                                 sum(tec_strg,
                                 invest_storage_power(r,tec_strg) * STORAGE_PROPERTIES(r,tec_strg,'cost_power')
                                 + invest_storage_energy(r,tec_strg) * STORAGE_PROPERTIES(r,tec_strg,'cost_energy')
                                 );
obj_gridcost(r)..                cost_gridexpansion(r)
                                 =E=
                                 sum(rr, invest_atc(r,rr)) / 2
                                 ;
* ------------------------------------------------------------------------------
* SUPPLY-DEMAND BALANCES
* ------------------------------------------------------------------------------
SD_balance_el(r,t)..
                                 sum(tec,q_gen(r,t,tec,'power'))
                                 + sum(tec_strg, q_store_out(r,t,tec_strg))
                                 + sum(tec_itm, GEN_PROFILE(r,t,tec_itm) * (INSTALLED_CAP_ITM(r,tec_itm) + invest_res(r,tec_itm)) )
                                 + FLOW_IMPORT(r,t)
                                 + q_nonserved(r,t,'power')
                                 =E=
                                 CONSUMPTION(r,t,'power')
                                 + sum(tec, q_fueluse(r,t,tec,'Power'))
                                 + sum(tec_strg, q_store_in(r,t,tec_strg))
                                 + FLOW_EXPORT(r,t)
                                 + sum(rr, flow(r,rr,t) )
                                 + q_curtail(r,t)
                                 ;
SD_balance_ht(r,t)..
                                 sum(tec,q_gen(r,t,tec,'heat'))
                                 + q_nonserved(r,t,'heat')
                                 =E=
                                 CONSUMPTION(r,t,'heat')
                                 ;
* ------------------------------------------------------------------------------
* THERMAL GENERATION
* ------------------------------------------------------------------------------
caplim_generation(r,t,tec,prd)..
                                 q_gen(r,t,tec,prd)
                                 =L=
                                 SMAX(l, FEASIBLE_OUTPUT(tec,l,prd)) * (NUM(r,tec) - decommission(r,tec) + invest_thermal(r,tec) )
                                 ;
nonchp_generation(r,t,tec)$(NOT tec_chp(tec))..
                                 sum(f, q_fueluse(r,t,tec,f) * EFFICIENCY(tec,'power',f) )
                                 =E=
                                 q_gen(r,t,tec,'power')
                                 ;
pth_generation(r,t,tec)$(tec_pth(tec))..
* replace sum(f,.) with q_fueluse(r,t,tec,'power') * EFFICIENCY(tec,'heat','power') ?
                                 sum(f, q_fueluse(r,t,tec,f) * EFFICIENCY(tec,'heat',f) )
                                 =E=
                                 q_gen(r,t,tec,'heat')
                                 ;
cc_a(r,t,tec)$tec_chp(tec)..
                                 Sum(l, cc_weights(r,t,tec,l))
                                 =E=
                                 (NUM(r,tec) - decommission(r,tec) + invest_thermal(r,tec) )
                                 ;
cc_b(r,t,tec,prd)$tec_chp(tec)..
                                 q_gen(r,t,tec,prd)
                                 =L=
                                 Sum(l, cc_weights(r,t,tec,l) * FEASIBLE_OUTPUT(tec,l,prd))
                                 ;
cc_c(r,t,tec,f)$tec_chp(tec)..
                                 q_fueluse(r,t,tec,f)
                                 =G=
                                 Sum(l, cc_weights(r,t,tec,l) * FEASIBLE_INPUT(tec,l,f) )
                                 ;

* ------------------------------------------------------------------------------
* ELECTRICITY STORAGES
* ------------------------------------------------------------------------------
storelim_out(r,t,tec_strg)..
                                 q_store_out(r,t,tec_strg)
                                 =L=
                                 STORAGE_PROPERTIES(r,tec_strg,'power_out')
                                 + invest_storage_power(r,tec_strg)
                                 ;
storelim_in(r,t,tec_strg)..
                                 q_store_in(r,t,tec_strg)
                                 =L=
                                 STORAGE_PROPERTIES(r,tec_strg,'power_in')
                                 + invest_storage_power(r,tec_strg)
                                 ;
storelim_storage(r,t,tec_strg)..
                                 storage_level(r,t,tec_strg)
                                 =L=
                                 STORAGE_PROPERTIES(r,tec_strg,'energy_max')
                                 + invest_storage_energy(r,tec_strg)
                                 ;
storage_balance(r,t,tec_strg)$(ord(t) > 1 AND STORAGE_PROPERTIES(r,tec_strg,'efficiency_out'))..
                                 storage_level(r,t,tec_strg)
                                 =E=
                                 storage_level(r,t-1,tec_strg)
                                 + RESERVOIR_INFLOWS(r,t,tec_strg)
                                 + q_store_in(r,t,tec_strg) * STORAGE_PROPERTIES(r,tec_strg,'efficiency_in')
                                 - q_store_out(r,t,tec_strg) / STORAGE_PROPERTIES(r,tec_strg,'efficiency_out')
                                 ;
storage_sizing(r,tec_strg)..
                                 invest_storage_energy(r,tec_strg)
                                 =G=
                                 invest_storage_power(r,tec_strg)
                                 ;

* ------------------------------------------------------------------------------
* international commercial electricity exchange
* ------------------------------------------------------------------------------
flow_balance(r,rr,t)$ATC(r,rr)..
                                 flow(r,rr,t)
                                 =E=
                                 -flow(rr,r,t)
                                 ;
flow_constraint_a(r,rr,t)$ATC(r,rr)..
                                 flow(r,rr,t)
                                 =L=
                                 ATC(r,rr) + invest_atc(r,rr)
                                 ;
flow_constraint_b(r,rr,t)$ATC(rr,r)..
                                 flow(r,rr,t)
                                 =G=
                                 - (ATC(rr,r) + invest_atc(rr,r))
                                 ;
atc_invest_symmetry(r,rr)..      invest_atc(r,rr)
                                 =E=
                                 invest_atc(rr,r)
                                 ;
* no flows from region to itself
flow.FX(r,rr,t)$(not ATC(r,rr))   = 0;
flow.FX(rr,r,t)$(not ATC(rr,r))   = 0;
* ------------------------------------------------------------------------------
* emissions
* ------------------------------------------------------------------------------
emission_calculation(r)..
                                 emissions(r)
                                 =E=
                                 sum((t,f), EMISSION_INTENSITY(f) * sum(tec,q_fueluse(r,t,tec,f)))
                                 ;
* ------------------------------------------------------------------------------
* decommissioning
* ------------------------------------------------------------------------------
decommission_limit(r,tec)..
                                 decommission(r,tec)
                                 =L=
                                 NUM(r,tec) + invest_thermal(r,tec)
                                 ;
* ------------------------------------------------------------------------------
* ancillary services
* ------------------------------------------------------------------------------
ancillary_service(r,t)..
                                 sum(tec$(NOT tec_chp(tec)), q_gen(r,t,tec,'power'))
                                 + sum(tec_strg, q_store_out(r,t,tec_strg))
                                 + sum(tec_strg, q_store_in(r,t,tec_strg))
                                 =G=
                                 0.175 * PEAK_LOAD(r)  # 0.125
                                 + 0.15 * sum(tec_itm$(NOT SAMEAS(tec_itm,'ror')),  # 0.075
                                 PEAK_PROFILE(r,tec_itm) * (INSTALLED_CAP_ITM(r,tec_itm) + invest_res(r,tec_itm))
                                 );
* ------------------------------------------------------------------------------
* curtail of intermittent generation only
* ------------------------------------------------------------------------------
curtail_limit(r,t)..             q_curtail(r,t)
                                 =L=
                                 sum(tec_itm$(NOT SAMEAS(tec_itm,'ror')),
                                     GEN_PROFILE(r,t,tec_itm) * (INSTALLED_CAP_ITM(r,tec_itm) + invest_res(r,tec_itm))
                                 );
* ------------------------------------------------------------------------------
* additional constraints
* ------------------------------------------------------------------------------

* restrict fuel use according to technology
q_fueluse.UP(r,t,tec,f)$(NOT sum(prd,EFFICIENCY(tec,prd,f))) = 0;

* bounds on investment -- long-term vs short-term model
invest_thermal.UP(r,tec) =       SWITCH_INVEST_THERM;
decommission.UP(r,tec) =         SWITCH_INVEST_THERM;
invest_res.UP(r,tec_itm) =       SWITCH_INVEST_ITM(r, tec_itm);
invest_storage_power.UP(r,tec_strg) = SWITCH_INVEST_STORAGE(r, tec_strg);
invest_storage_energy.UP(r,tec_strg) = SWITCH_INVEST_STORAGE(r, tec_strg);
invest_atc.UP(r,rr) =            SWITCH_INVEST_ATC(r,rr);

* ==============================================================================
* include specific changes
* ==============================================================================
$if not set project $goto next
$include medea_%project%.gms
* ==============================================================================
$label next

model medea / all /;

********************************************************************************
******* set starting values
*q_gen.FX(r,start_t,tec,prd)      $INIT_GEN(r,start_t,tec,prd)            = INIT_GEN(r,start_t,tec,prd);
*q_store_in.FX(r,start_t,tec_strg)     $INIT_PUMP(r,start_t,tec_strg)           = INIT_PUMP(r,start_t,tec_strg);
*q_store_out.FX(r,start_t,tec_strg)  $INIT_TURB(r,start_t,tec_strg)           = INIT_TURB(r,start_t,tec_strg);
*res_level.FX(r,start_t,tec_strg)  $INIT_STORAGE(r,start_t,tec_strg)        = INIT_STORAGE(r,start_t,tec_strg);
*res_level.FX(r,end_t,tec_strg)    $FINAL_STORAGE(r,end_t,tec_strg)         = FINAL_STORAGE(r,end_t,tec_strg);

options
*LP = OSIGurobi,
reslim = 54000,
threads = 8,
optCR = 0.01,
BRatio = 1
;

$onecho > osigurobi.opt
workerPool nora.boku.ac.at:9797
workerPassword keepulbooleatias
ConcurrentJobs 2
method 1
$offecho

*medea.OptFile = 1;

solve medea using LP minimizing syscost;

********************************************************************************
******* reporting

******* solution details
scalars modelStat, solveStat;
modelStat = medea.modelstat;
solveStat = medea.solvestat;

****** exogenous parameters
parameters
ANNUAL_CONSUMPTION(r,prd),
FULL_LOAD_HOURS(r,tec_itm),
AVG_PRICE(r,f),
AVG_PRICE_DA(r),
AVG_PRICE_EUA(r);

ANNUAL_CONSUMPTION(r,prd) = sum(t, CONSUMPTION(r,t,prd));
FULL_LOAD_HOURS(r,tec_itm) = sum(t, GEN_PROFILE(r,t,tec_itm));
AVG_PRICE(r,f) = sum(t, PRICE_FUEL(t,r,f)) / card(t);
AVG_PRICE_DA(r) = sum(t, PRICE_DA(t,r)) / card(t);
AVG_PRICE_EUA(r) = sum(t, PRICE_EUA(t,r)) / card(t);

display ANNUAL_CONSUMPTION, FULL_LOAD_HOURS, AVG_PRICE, AVG_PRICE_DA, AVG_PRICE_EUA

******* system operations
parameter
annual_generation(r,prd),
annual_generation_by_tec(r,tec,prd),
annual_pumping(r),
annual_turbining(r),
annual_netflow(r),
annual_fueluse(r,f),
annual_fixedexports,
annual_fixedimports,
annual_curtail(r);

annual_generation(r,prd) = sum((t,tec), q_gen.L(r, t, tec, prd));
annual_generation_by_tec(r,tec,prd) = sum(t, q_gen.L(r, t, tec, prd));
annual_pumping(r) = sum((t,tec_strg), q_store_in.L(r,t,tec_strg));
annual_turbining(r) = sum((t,tec_strg), q_store_out.L(r,t,tec_strg));
annual_netflow(rr) = sum(t, flow.L('AT',rr,t));
annual_fueluse(r,f) = sum((t,tec), q_fueluse.L(r,t,tec,f));
annual_fixedexports = sum(t, FLOW_EXPORT('AT',t));
annual_fixedimports = sum(t, FLOW_IMPORT('AT',t));
annual_curtail(r) = sum(t, q_curtail.L(r,t));

display annual_generation, annual_netflow, annual_fueluse, annual_fixedexports, annual_fixedimports, annual_curtail;

******* annual values
parameters
ann_value_generation(r,prd),
ann_value_generation_by_tec(r,tec,prd),
ann_value_pumping(r),
ann_value_turbining(r),
ann_value_flows(r,rr),
ann_value_curtail(r);

ann_value_generation(r,prd) = sum((t,tec), SD_balance_el.M(r,t) * q_gen.L(r, t, tec, prd));
ann_value_generation_by_tec(r,tec,prd) = sum(t, SD_balance_el.M(r,t) * q_gen.L(r, t, tec, prd));
ann_value_pumping(r) = sum((t,tec_strg), SD_balance_el.M(r,t) * q_store_in.L(r,t,tec_strg));
ann_value_turbining(r) = sum((t,tec_strg), SD_balance_el.M(r,t) * q_store_out.L(r,t,tec_strg));
ann_value_flows(r,rr) = sum(t, SD_balance_el.M(r,t) * flow.L(r,rr,t));
ann_value_curtail(r) = sum(t, SD_balance_el.M(r,t) * q_curtail.L(r,t));

display ann_value_generation, ann_value_generation_by_tec, ann_value_pumping, ann_value_turbining, ann_value_flows, ann_value_curtail;

******* prices, cost, producer surplus
parameter
annual_price_el(r),
annual_price_ht(r),
annual_cost(r,tec),
annual_revenue(r,tec),
annual_surplus_therm(r,tec),
annual_surplus_stor(r,tec_strg),
producer_surplus(r);

annual_price_el(r) = sum(t, SD_balance_el.M(r,t))/card(t);
annual_price_ht(r) = sum(t, SD_balance_ht.M(r,t))/card(t);
annual_cost(r,tec) = sum(t, cost_fuel.L(r,t,tec)
                         + cost_emission.L(r,t,tec)
                         + sum(prd, OM_VARIABLE_COST(tec) * q_gen.L(r,t,tec,prd)));
annual_revenue(r,tec) = sum(t,
                         SD_balance_el.M(r,t) * q_gen.L(r,t,tec,'power')
                         + SD_balance_ht.M(r,t) * q_gen.L(r,t,tec,'heat'));
annual_surplus_therm(r,tec) =   sum(t,
                         SD_balance_el.M(r,t) * q_gen.L(r,t,tec,'power')
                         + SD_balance_ht.M(r,t) * q_gen.L(r,t,tec,'heat')
                         - cost_fuel.L(r,t,tec)
                         - cost_emission.L(r,t,tec)
                         - sum(prd, OM_VARIABLE_COST(tec) * q_gen.L(r,t,tec,prd))
                         );
annual_surplus_stor(r,tec_strg) = sum(t,
                         SD_balance_el.M(r,t) * q_store_out.L(r,t,tec_strg)
                         - SD_balance_el.M(r,t) * q_store_in.L(r,t,tec_strg)
                         );
producer_surplus(r) =    sum(tec, annual_surplus_therm(r,tec))
                         + sum(tec_strg, annual_surplus_stor(r,tec_strg))
                         ;

display
annual_price_el, annual_price_ht, annual_cost, annual_surplus_therm, annual_surplus_stor, producer_surplus;

parameter AV_CAP(r, tec, prd);
AV_CAP(r,tec,prd) = smax(l, FEASIBLE_OUTPUT(tec,l,prd)) * NUM(r,tec);
display NUM, av_cap;

******* marginals of equations
parameter
hourly_price_el(r,t),
hourly_price_ht(r,t),
hourly_price_ancillary(r,t),
hourly_price_exports(r,rr,t)
;

hourly_price_el(r,t) = SD_balance_el.M(r,t);
hourly_price_ht(r,t) = SD_balance_ht.M(r,t);
hourly_price_ancillary(r,t) = ancillary_service.M(r,t);
hourly_price_exports(r,rr,t) = flow_balance.M(r,rr,t);
