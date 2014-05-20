using MixedModels
using Base.Test

const LETTERS = map(string,'A':'Z')
const letters = map(string,'a':'z')

## Dyestuff data from lme4
ds = DataFrame(Yield = [1545.,1440.,1440.,1520.,1580.,1540.,1555.,1490.,1560.,1495.,
                        1595.,1550.,1605.,1510.,1560.,1445.,1440.,1595.,1465.,1545.,
                        1595.,1630.,1515.,1635.,1625.,1520.,1455.,1450.,1480.,1445.],
               Batch = pool(rep(LETTERS[1:6],1,5)))

lm1 = lmm(Yield ~ 1 | Batch,ds)

@test typeof(lm1) == LMMScalar1
@test size(lm1) == (30,1,6,1)
@test lm1.Ztnz == ones(30)
@test lm1.Ztrv == rep(uint8([1:6]),1,5)
@test lm1.Xt == ones((1,30))
@test length(lm1.theta) == 1
@test lm1.ZtZ == fill(5.,6)

fit(lm1)

@test_approx_eq theta(lm1) [0.752583753954506]
@test_approx_eq deviance(lm1) 327.3270598812219
@test_approx_eq fixef(lm1) [1527.5]
@test_approx_eq coef(lm1) [1527.5]
@test_approx_eq ranef(lm1) [-16.62825692795362 0.3695168206213314 26.974727905347223 -21.801492416650333 53.579938990073295 -42.49443437143737]
@test_approx_eq ranef(lm1,true) [-22.094892217084453 0.49099760482428484 35.84282515215955 -28.968858684621885 71.19465269949505 -56.46472455477185]
@test_approx_eq std(lm1) [37.260474496612346,49.51007020922851]
@test_approx_eq logdet(lm1) 2.057833608046211
@test_approx_eq logdet(lm1,false) 8.060182641695667
@test_approx_eq scale(lm1) 49.51007020922851
@test_approx_eq scale(lm1,true) 2451.247052122736
@test_approx_eq pwrss(lm1) 73537.41156368208
@test_approx_eq stderr(lm1) [17.694596021277448]

fit(reml!(lm1))

@test_approx_eq std(lm1) [42.00063130711604,49.510093347813246]
@test_approx_eq fixef(lm1) [1527.5]     # unchanged because of balanced design
@test_approx_eq coef(lm1) [1527.5]
@test_approx_eq stderr(lm1) [19.383424615110936]
@test_approx_eq objective(lm1) 319.6542768422625

## Dyestuff2 data from lme4
ds[:Yield] = [7.298,3.846,2.434,9.566,7.99,5.22,6.556,0.608,11.788,-0.892,0.11,
              10.386,13.434,5.51,8.166,2.212,4.852,7.092,9.288,4.98,0.282,9.014,
              4.458,9.446,7.198,1.722,4.782,8.106,0.758,3.758]

lm2 = fit(lmm(Yield ~ 1|Batch, ds))

@test_approx_eq deviance(lm2) 162.87303665382575
@test_approx_eq std(lm2) [0.0,3.653231351374652]
@test_approx_eq stderr(lm2) [0.6669857396443261]
@test_approx_eq coef(lm2) [5.6656]
@test_approx_eq logdet(lm2,false) 0.0
@test_approx_eq logdet(lm2) 3.4011973816621555

## sleepstudy data from lme4

slp = DataFrame(Reaction =
                [249.56,258.7047,250.8006,321.4398,356.8519,414.6901,382.2038,
                 290.1486,430.5853,466.3535,222.7339,205.2658,202.9778,204.707,
                 207.7161,215.9618,213.6303,217.7272,224.2957,237.3142,199.0539,
                 194.3322,234.32,232.8416,229.3074,220.4579,235.4208,255.7511,
                 261.0125,247.5153,321.5426,300.4002,283.8565,285.133,285.7973,
                 297.5855,280.2396,318.2613,305.3495,354.0487,287.6079,285.0,
                 301.8206,320.1153,316.2773,293.3187,290.075,334.8177,293.7469,
                 371.5811,234.8606,242.8118,272.9613,309.7688,317.4629,309.9976,
                 454.1619,346.8311,330.3003,253.8644,283.8424,289.555,276.7693,
                 299.8097,297.171,338.1665,332.0265,348.8399,333.36,362.0428,
                 265.4731,276.2012,243.3647,254.6723,279.0244,284.1912,305.5248,
                 331.5229,335.7469,377.299,241.6083,273.9472,254.4907,270.8021,
                 251.4519,254.6362,245.4523,235.311,235.7541,237.2466,312.3666,
                 313.8058,291.6112,346.1222,365.7324,391.8385,404.2601,416.6923,
                 455.8643,458.9167,236.1032,230.3167,238.9256,254.922,250.7103,
                 269.7744,281.5648,308.102,336.2806,351.6451,256.2968,243.4543,
                 256.2046,255.5271,268.9165,329.7247,379.4445,362.9184,394.4872,
                 389.0527,250.5265,300.0576,269.8939,280.5891,271.8274,304.6336,
                 287.7466,266.5955,321.5418,347.5655,221.6771,298.1939,326.8785,
                 346.8555,348.7402,352.8287,354.4266,360.4326,375.6406,388.5417,
                 271.9235,268.4369,257.2424,277.6566,314.8222,317.2135,298.1353,
                 348.1229,340.28,366.5131,225.264,234.5235,238.9008,240.473,
                 267.5373,344.1937,281.1481,347.5855,365.163,372.2288,269.8804,
                 272.4428,277.8989,281.7895,279.1705,284.512,259.2658,304.6306,
                 350.7807,369.4692,269.4117,273.474,297.5968,310.6316,287.1726,
                 329.6076,334.4818,343.2199,369.1417,364.1236],
                Days = rep(0:9,18),
                Subject = pool(rep(1:18,1,10)))
lm3 = lmm(Reaction ~ Days + (Days|Subject), slp)

@test typeof(lm3) == LMMVector1
@test size(lm3) == (180,2,36,1)
@test theta(lm3) == [1.,0.,1.]
@test lower(lm3) == [0.,-Inf,0.]

fit(lm3)

@test_approx_eq deviance(lm3) 1751.9393445070389
@test_approx_eq objective(lm3) 1751.9393445070389
@test_approx_eq coef(lm3) [251.40510484848477,10.4672859595959]
@test_approx_eq fixef(lm3) [251.40510484848477,10.4672859595959]
@test_approx_eq stderr(lm3) [6.632246393560379,1.5021906049257874]
@test_approx_eq theta(lm3) [0.9292135717779286,0.01816527132483433,0.22263562408913878]
@test_approx_eq std(lm3) [23.78491450663324,5.69767584038342,25.591932394890165]
@test_approx_eq logdet(lm3) 8.390477202368283
@test_approx_eq logdet(lm3,false) 73.90169459565723
@test diag(cor(lm3)) == ones(2)
@test_approx_eq triu(cholfact(lm3).UL) reshape([3.895748717859,0.0,2.366052882028106,17.036408236726047],(2,2))

fit(reml!(lm3))
                                        # fixed-effects estimates unchanged
@test_approx_eq coef(lm3) [251.40510484848477,10.4672859595959]
@test_approx_eq fixef(lm3) [251.40510484848477,10.4672859595959]
@test_approx_eq stderr(lm3) [6.669402126263169,1.510606304414797]
@test_approx_eq theta(lm3) [0.9292135717779286,0.018165271324834312,0.22263562408913865]
@test isnan(deviance(lm3))
@test_approx_eq objective(lm3) 1743.67380643908
@test_approx_eq std(lm3) [23.918164370001566,5.7295958427461064,25.735305686982493]
@test_approx_eq triu(cholfact(lm3).UL) reshape([3.8957487178589947,0.0,2.3660528820280797,17.036408236726015],(2,2))

const bb = rep(LETTERS[1:10],1,6)
const cc = rep(letters[1:3],10,2)

psts = DataFrame(Strength = [62.8,62.6,60.1,62.3,62.7,63.1,60.0,61.4,57.5,56.9,61.1,58.9,
                             58.7,57.5,63.9,63.1,65.4,63.7,57.1,56.4,56.9,58.6,64.7,64.5,
                             55.1,55.1,54.7,54.2,58.8,57.5,63.4,64.9,59.3,58.1,60.5,60.0,
                             62.5,62.6,61.0,58.7,56.9,57.7,59.2,59.4,65.2,66.0,64.8,64.1,
                             54.8,54.8,64.0,64.0,57.7,56.8,58.3,59.3,59.2,59.2,58.9,56.6],
                 Batch = pool(bb),
                 Cask = pool(cc),
                 Sample = pool(map(*,bb,cc)))
