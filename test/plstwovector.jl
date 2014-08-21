bs10 = DataFrame(read_rda(Pkg.dir("MixedModels","data","bs10.rda"))["bs10"])

lmm₆ = lmm(dif ~ S+F+SF + (S+F+SF|SubjID) + (S+F+SF|ItemID),bs10);

@test typeof(lmm₆) == LinearMixedModel{PLSTwo}
@test size(lmm₆) == (1104,4,416,2)
@test size(lmm₆.s) == (4,4,4,92,12,368,48)
θ = float([1,0,0,0,1,0,0,1,0,1,1,0,0,0,1,0,0,1,0,1])
@test MixedModels.θ(lmm₆) == θ
@test lower(lmm₆) == [(t == 0. ? -Inf : 0.)::Float64 for t in θ]

fit(lmm₆)

@test_approx_eq_eps deviance(lmm₆) 1030.9552950677933 1.e-6
@test_approx_eq_eps objective(lmm₆) 1030.9552950677933 1.e-6
@test_approx_eq_eps coef(lmm₆) [0.03922101449275361,-0.01740942028985504,0.017481884057970985,-0.03226449275362319] 1.e-6
@test_approx_eq_eps fixef(lmm₆) [0.03922101449275361,-0.01740942028985504,0.017481884057970985,-0.03226449275362319] 1.e-6
@test_approx_eq_eps stderr(lmm₆) [0.016932881777342586,0.015628925278377854,0.012794734517420898,0.013383264108892194] 1.e-6
@test_approx_eq_eps MixedModels.θ(lmm₆) [0.3237543059667476,-0.16633861244889625,0.16111944089337082,-0.026565210134809787,0.2451721509909395,-0.020854427802271307,0.19981057336466995,0.0,6.188468694448198e-6,9.564823556530626e-6,0.048840692065689854,-0.024908781749325627,0.032582342573485426,-0.025527501541498555,0.0,2.0842813380332083e-7,-1.8676467080265794e-6,0.0,-8.233801202660107e-8,0.0] 1.e-5
@test_approx_eq_eps std(lmm₆)[1] [0.11572978641823575,0.10590640720808188,0.05807448166558712,0.07205313472757559] 1.e-4
@test_approx_eq_eps std(lmm₆)[2] [0.017458680107444353,0.00890393714820269,0.011646941762991407,0.009125105843115275] 1.e-6
@test_approx_eq_eps scale(lmm₆) 0.35746176741236063 1.e-6
@test_approx_eq_eps logdet(lmm₆) 26.078415642792358 1.e-4
@test_approx_eq_eps logdet(lmm₆,false) 169.36793579667008 1.e-3

fit(reml!(lmm₆))

@test isnan(deviance(lmm₆))
@test_approx_eq_eps objective(lmm₆) 1057.8890104656941 1.e-6
@test_approx_eq_eps coef(lmm₆) [0.03922101449275352,-0.017409420289855045,0.01748188405797096,-0.032264492753623204] 1.e-6
@test_approx_eq_eps fixef(lmm₆) [0.03922101449275352,-0.017409420289855045,0.01748188405797096,-0.032264492753623204] 1.e-6
@test_approx_eq_eps stderr(lmm₆) [0.017093505356537114,0.01570684526390603,0.012911840199026876,0.013493138097599696] 1.e-6
#@test_approx_eq_eps MixedModels.θ(lmm₆) [0.3237543059667476,-0.16633861244889625,0.16111944089337082,-0.026565210134809787,0.24517215099093947,-0.020854427802271307,0.19981057336466995,0.0,5.750877876547699e-6,1.883954519306984e-6,0.04884069206568986,-0.024908781749325627,0.032582342573485426,-0.025527501541498555,0.0,2.0842813380332083e-7,-1.8676467080265794e-6,0.0,-8.233801202660107e-8,0.0] 1.e-5
@test_approx_eq_eps std(lmm₆)[1] [0.1165682588673791,0.10672535496449256,0.0584683086534313,0.07272067618942804] 1.e-6
@test_approx_eq_eps std(lmm₆)[2] [0.018503979791644917,0.009125738185308792,0.012775022711223294,0.010173996163511669] 1.e-6
@test_approx_eq_eps scale(lmm₆) 0.35779465233631413 1.e-6
@test_approx_eq_eps logdet(lmm₆) 26.0390493574181 1.e-5
@test_approx_eq_eps logdet(lmm₆,false) 171.33650680732632 1.e-4
