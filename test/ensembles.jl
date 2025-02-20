module TestEnsembles

using Test
using Random
using StableRNGs
using MLJEnsembles
using MLJBase
using ..Models
using CategoricalArrays
import Distributions
using StatisticalMeasures

## HELPER FUNCTIONS

@test MLJEnsembles._reducer([1, 2], [3, ]) == [1, 2, 3]
@test MLJEnsembles._reducer(([1, 2], [:x, :y]), ([3, 4, 5], [:z, :w, :a])) ==
    ([1, 2, 3, 4, 5], [:x, :y, :z, :w, :a])

pair_vcat(p, q) = (vcat(p[1], q[1]), vcat(p[2], q[2]))


## WRAPPED ENSEMBLES OF FITRESULT

# target is :deterministic :multiclass false:
atom = DeterministicConstantClassifier()
L = ['a', 'b', 'j']
L2 = categorical(L)
ensemble = [L2[1], L2[3], L2[3], L2[2]]
n=length(ensemble)
atomic_weights = fill(1/n, n) # ignored by predict below
wens = MLJEnsembles.WrappedEnsemble(atom, ensemble)
X = MLJEnsembles.table(rand(3,5))
@test predict(wens, atomic_weights, X) ==
    categorical(vcat(['j','j','j'],L))[1:3]

# target is :deterministic :continuous false:
atom = DeterministicConstantRegressor()
ensemble = Float64[4, 7, 4, 4]
atomic_weights = [0.1, 0.5, 0.2, 0.2]
wens = MLJEnsembles.WrappedEnsemble(atom, ensemble)
@test predict(wens, atomic_weights, X) ≈ [5.5, 5.5, 5.5]

# target is :probabilistic :multiclass false:
atom = ConstantClassifier()
L = categorical(['a', 'b', 'j'])
d1 = UnivariateFinite(L, [0.1, 0.2, 0.7])
fitresult1 = d1
d2 = UnivariateFinite(L, [0.2, 0.3, 0.5])
fitresult2 = d2
ensemble = [fitresult2, fitresult1, fitresult2, fitresult2]
atomic_weights = [0.1, 0.5, 0.2, 0.2]
wens = MLJEnsembles.WrappedEnsemble(atom, ensemble)
X = MLJEnsembles.table(rand(2,5))
d = predict(wens, atomic_weights, X)[1]
@test pdf(d, 'a') ≈ 0.15
@test pdf(d, 'b') ≈ 0.25
@test pdf(d, 'j') ≈ 0.6

# target is :probabilistic :continuous false:
atom = ConstantRegressor()
d1 = Distributions.Normal(1, 2)
d2 = Distributions.Normal(3, 4)
ensemble = [d2,  d1, d2, d2]
atomic_weights = [0.1, 0.5, 0.2, 0.2]
wens = MLJEnsembles.WrappedEnsemble(atom, ensemble)
X = MLJEnsembles.table(rand(2,5))
d = predict(wens, atomic_weights, X)[1]


## ENSEMBLE MODEL

# target is :deterministic :multiclass false:
atom=DeterministicConstantClassifier()
X = MLJEnsembles.table(ones(5,3))
y = categorical(collect("asdfa"))
train, test = partition(1:length(y), 0.8);
ensemble_model = EnsembleModel(model=atom)
ensemble_model.n = 10
fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y)
predict(ensemble_model, fitresult, MLJEnsembles.selectrows(X, test))
atomic_weights = rand(10)
atomic_weights = atomic_weights/sum(atomic_weights)
ensemble_model.atomic_weights = atomic_weights
fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y)
p = predict(ensemble_model, fitresult, MLJEnsembles.selectrows(X, test))
@test MLJBase.target_scitype(ensemble_model) == MLJBase.target_scitype(atom)

# target is :deterministic :continuous false:
atom = DeterministicConstantRegressor()
X = MLJEnsembles.table(ones(5,3))
y = Float64[1.0, 2.0, 1.0, 1.0, 1.0]
train, test = partition(1:length(y), 0.8);
ensemble_model = EnsembleModel(model=atom)
ensemble_model.n = 10
fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y)
@test reduce(* , [x ≈ 1.0 || x ≈ 1.25 for x in fitresult.ensemble])
predict(ensemble_model, fitresult, MLJEnsembles.selectrows(X, test))
ensemble_model.bagging_fraction = 1.0
fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y)
@test unique(fitresult.ensemble) ≈ [1.2]
predict(ensemble_model, fitresult, MLJEnsembles.selectrows(X, test))
atomic_weights = rand(10)
atomic_weights = atomic_weights/sum(atomic_weights)
ensemble_model.atomic_weights = atomic_weights
predict(ensemble_model, fitresult, MLJEnsembles.selectrows(X, test))

# target is :deterministic :continuous false:
atom = DeterministicConstantRegressor()
rng = StableRNG(1234)
X = MLJEnsembles.table(randn(rng, 10, 3))
y = selectcols(X, 1)
std(y)
train, test = partition(1:length(y), 0.8);
ensemble_model = EnsembleModel(model=atom, rng=rng)
ensemble_model.out_of_bag_measure = [rms, rmsp]
ensemble_model.n = 10
fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y)
# TODO: the following test fails in distributed version (because of
# multiple rng's ?)
@test abs(report.oob_measurements[1] - std(y)) < 0.25
ensemble_model = EnsembleModel(model=atom,rng=Random.MersenneTwister(1))
ensemble_model.out_of_bag_measure = rms
ensemble_model.n = 2
fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y)

# target is :probabilistic :multiclass false:
atom = ConstantClassifier()
X = MLJEnsembles.table(ones(5,3))
y = categorical(collect("asdfa"))
train, test = partition(1:length(y), 0.8);
ensemble_model = EnsembleModel(model=atom)
ensemble_model.n = 10
fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y)
fitresult.ensemble
predict(ensemble_model, fitresult, MLJEnsembles.selectrows(X, test))
ensemble_model.bagging_fraction = 1.0
fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y)
fitresult.ensemble
d = predict(ensemble_model, fitresult, MLJEnsembles.selectrows(X, test))[1]
@test pdf(d, 'a') ≈ 2/5
@test pdf(d, 's') ≈ 1/5
@test pdf(d, 'd') ≈ 1/5
@test pdf(d, 'f') ≈ 1/5
@test mode(d) == 'a'
atomic_weights = rand(10)
atomic_weights = atomic_weights/sum(atomic_weights)
ensemble_model.atomic_weights = atomic_weights
predict(ensemble_model, fitresult, MLJEnsembles.selectrows(X, test))

# test sample weights
w = [1,100,1,1,1]
fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y, w)
p2 = predict(ensemble_model, fitresult, MLJEnsembles.selectrows(X, test))
@test mode(p2[1] ) == 's'

# target is :probabilistic :continuous false:
atom = ConstantRegressor()
X = MLJEnsembles.table(ones(5,3))
y = Float64[1.0, 2.0, 2.0, 1.0, 1.0]
train, test = partition(1:length(y), 0.8);
ensemble_model = EnsembleModel(model=atom)
ensemble_model.n = 10
fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y)
d1 = Distributions.fit(Distributions.Normal, [1,1,2,2])
d2 = Distributions.fit(Distributions.Normal, [1,1,1,2])
# @test reduce(* , [d.μ ≈ d1.μ || d.μ ≈ d2.μ for d in fitresult.ensemble])
# @test reduce(* , [d.σ ≈ d1.σ || d.σ ≈ d2.σ for d in fitresult.ensemble])
d=predict(ensemble_model, fitresult, MLJEnsembles.selectrows(X, test))[1]
for dc in d.components
    @test pdf(dc, 1.52) ≈ pdf(d1, 1.52) || pdf(dc, 1.52) ≈ pdf(d2, 1.52)
end
ensemble_model.bagging_fraction = 1.0
fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y)
d = predict(ensemble_model, fitresult, MLJEnsembles.selectrows(X, test))[1]
d3 = Distributions.fit(Distributions.Normal, y)
@test pdf(d, 1.52) ≈ pdf(d3, 1.52)
atomic_weights = rand(10)
atomic_weights = atomic_weights/sum(atomic_weights)
ensemble_model.atomic_weights = atomic_weights
predict(ensemble_model, fitresult, MLJEnsembles.selectrows(X, test))

# @test MLJBase.output_is(ensemble_model) == MLJBase.output_is(atom)

# test generic constructor:
@test EnsembleModel(model=ConstantRegressor()) isa Probabilistic
@test EnsembleModel(model=DeterministicConstantRegressor()) isa Deterministic

@testset "further test of sample weights" begin
    ## Note: This testset also indirectly tests for compatibility with the data-front end
    # implemented by `KNNClassifier` as calls to `fit`/`predict` on an `Ensemble` model 
    # with `atom=KNNClassifier` would error if the ensemble implementation doesn't handle
    # data front-end conversions properly.
    
    rng = StableRNG(123)
    N = 20
    X = (x = rand(rng, 3N), );
    y = categorical(rand(rng, "abbbc", 3N));
    atom = KNNClassifier()

    ensemble_model = EnsembleModel(model=atom,
                                   bagging_fraction=1,
                                   n = 5, rng=rng)
    fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y)
    @test predict_mode(ensemble_model, fitresult, (x = [0, ],))[1] == 'b'
    w = map(y) do η
        η == 'a' ? 100 : 1
    end
    fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y, w)
    @test predict_mode(ensemble_model, fitresult, (x = [0, ],))[1] == 'a'

    ensemble_model.rng = 1234 # always start with same rng
    ensemble_model.bagging_fraction=0.6
    ensemble_model.out_of_bag_measure = [BrierScore(), cross_entropy]
    fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y)
    m1 = report.oob_measurements[1]
    fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y)
    m2 = report.oob_measurements[1]
    @test m1 == m2
    # supplying sample weights should change the oob meausurements for
    # measures that support weights:
    fitresult, cache, report = MLJEnsembles.fit(ensemble_model, 0, X, y, w)
    m3 = report.oob_measurements[1]
    @test !(m1 ≈ m3)
end


## MACHINE TEST 
## (INCLUDES TEST OF UPDATE.
## ALSO INCLUDES COMPATIBILITY TESTS FOR ENSEMBLES WITH ATOM MODELS HAVING A 
## DIFFERENT DATA FRONT-END SEE #16)

@testset "machine tests" begin
    N =100
    X = (x1=rand(N), x2=rand(N), x3=rand(N))
    y = 2X.x1  - X.x2 + 0.05*rand(N)

    atom = KNNRegressor(K=7)
    ensemble_model = EnsembleModel(model=atom)
    ensemble = machine(ensemble_model, X, y)
    train, test = partition(eachindex(y), 0.7)
    fit!(ensemble, rows=train, verbosity=0)
    @test length(ensemble.fitresult.ensemble) == ensemble_model.n
    ensemble_model.n = 15
    @test_logs((:info, r"Training"),
            fit!(ensemble, verbosity=1))
    @test length(ensemble.fitresult.ensemble) == 15
    ensemble_model.n = 20
    @test_logs((:info, r"Updating"),
            (:info, r"Building"),
            fit!(ensemble))
    @test length(ensemble.fitresult.ensemble) == 20
    ensemble_model.n = 5
    @test_logs((:info, r"Updating"),
            (:info, r"Truncating"),
            fit!(ensemble))
    @test length(ensemble.fitresult.ensemble) == 5

    @test !isnan(predict(ensemble, MLJEnsembles.selectrows(X, test))[1])

    # tests using integer rngs (see issue 27)
    X_, y_ = @load_iris
    atom = KNNClassifier(K = 7)
    ensemble_model = EnsembleModel(
        atom;
        bagging_fraction=0.6,
        rng=123,
        out_of_bag_measure = [log_loss, brier_score]
    )
    ensemble = machine(ensemble_model, X_, y_)
    fit!(ensemble)
    @test length(ensemble.fitresult.ensemble) == ensemble_model.n

end


end

true
