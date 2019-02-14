import Foundation

public class ForWriterT {}
public typealias WriterTOf<F, W, A> = Kind3<ForWriterT, F, W, A>
public typealias WriterTPartial<F, W> = Kind2<ForWriterT, F, W>

public class WriterT<F, W, A> : WriterTOf<F, W, A> {
    fileprivate let value : Kind<F, (W, A)>
    
    public static func pure<Mono, Appl>(_ a : A, _ monoid : Mono, _ applicative : Appl) -> WriterT<F, W, A> where Mono : Monoid, Mono.A == W, Appl : Applicative, Appl.F == F {
        return WriterT(applicative.pure((monoid.empty, a)))
    }
    
    public static func both<Appl>(_ w : W, _ a : A, _ applicative : Appl) -> WriterT<F, W, A> where Appl : Applicative, Appl.F == F {
        return WriterT(applicative.pure((w, a)))
    }
    
    public static func fromTuple<Appl>(_ z : (W, A), _ applicative : Appl) -> WriterT<F, W, A> where Appl : Applicative, Appl.F == F {
        return WriterT(applicative.pure(z))
    }
    
    public static func putT<Func>(_ fa : Kind<F, A>, _ w : W, _ functor : Func) -> WriterT<F, W, A> where Func : Functor, Func.F == F {
        return WriterT(functor.map(fa, { a in (w, a) }))
    }
    
    public static func put<Appl>(_ a : A, _ w : W, _ applicative : Appl) -> WriterT<F, W, A> where Appl : Applicative, Appl.F == F {
        return WriterT.putT(applicative.pure(a), w, applicative)
    }
    
    public static func putT2<Func>(_ vf : Kind<F, A>, _ w : W, _ functor : Func) -> WriterT<F, W, A> where Func : Functor, Func.F == F {
        return WriterT(functor.map(vf, { v in (w, v) }))
    }
    
    public static func put2<Appl>(_ a : A, _ w : W, _ applicative : Appl) -> WriterT<F, W, A> where Appl : Applicative, Appl.F == F {
        return WriterT.putT2(applicative.pure(a), w, applicative)
    }

    public static func tell<Appl>(_ l : W, _ applicative : Appl) -> WriterT<F, W, Unit> where Appl : Applicative, Appl.F == F {
        return WriterT<F, W, Unit>.put(unit, l, applicative)
    }
    
    public static func value<Appl, Mono>(_ a : A, _ applicative : Appl, _ monoid : Mono) -> WriterT<F, W, A> where Appl : Applicative, Appl.F == F, Mono : Monoid, Mono.A == W {
        return WriterT.put(a, monoid.empty, applicative)
    }
    
    public static func valueT<Func, Mono>(_ fa : Kind<F, A>, _ functor : Func, _ monoid : Mono) -> WriterT<F, W, A> where Func : Functor, Func.F == F, Mono : Monoid, Mono.A == W {
        return WriterT.putT(fa, monoid.empty, functor)
    }
    
    public static func empty<MonoK>(_ monoidK : MonoK) -> WriterT<F, W, A> where MonoK : MonoidK, MonoK.F == F {
        return WriterT(monoidK.emptyK())
    }
    
    public static func pass<Mon>(_ fa : WriterT<F, W, ((W) -> W, A)>, _ monad : Mon) -> WriterT<F, W, A> where Mon : Monad, Mon.F == F {
        return WriterT(monad.flatMap(fa.content(monad), { tuple2FA in monad.map(fa.write(monad), { l in (tuple2FA.0(l), tuple2FA.1) }) }))
    }
    
    public static func tailRecM<B, Mon>(_ a : A, _ f : @escaping (A) -> Kind<WriterTPartial<F, W>, Either<A, B>>, _ monad : Mon) -> WriterT<F, W, B> where Mon : Monad, Mon.F == F {
        return WriterT<F, W, B>(monad.tailRecM(a, { inA in
            monad.map(WriterT<F, W, Either<A, B>>.fix(f(inA)).value, { pair in
                pair.1.fold(Either<A, (W, B)>.left,
                            { b in Either<A, (W, B)>.right((pair.0, b)) })
            })
        }))
    }
    
    public static func fix(_ fa : WriterTOf<F, W, A>) -> WriterT<F, W, A> {
        return fa as! WriterT<F, W, A>
    }
    
    public init(_ value : Kind<F, (W, A)>) {
        self.value = value
    }
    
    public func map<B, Func>(_ f : @escaping (A) -> B, _ functor : Func) -> WriterT<F, W, B> where Func : Functor, Func.F == F {
        return WriterT<F, W, B>(functor.map(value, { pair in (pair.0, f(pair.1)) }))
    }
    
    public func mapAcc<U, Mon>(_ f : @escaping (W) -> U, _ monad : Mon) -> WriterT<F, U, A> where Mon : Monad, Mon.F == F {
        return transform({ pair in (f(pair.0), pair.1) }, monad)
    }
    
    public func bimap<B, U, Mon>(_ g : @escaping (W) -> U, _ f : @escaping (A) -> B, _ monad : Mon) -> WriterT<F, U, B> where Mon : Monad, Mon.F == F {
        return transform({ pair in (g(pair.0), f(pair.1))}, monad)
    }
    
    public func liftF<B, Appl>(_ fb : Kind<F, B>, _ applicative : Appl) -> WriterT<F, W, B> where Appl : Applicative, Appl.F == F {
        return WriterT<F, W, B>(applicative.map2(fb, value, { x, y in (y.0, x) }))
    }
    
    public func ap<AA, B, SemiG, Mon>(_ fa : WriterT<F, W, AA>, _ semigroup : SemiG, _ monad : Mon) -> WriterT<F, W, B> where SemiG : Semigroup, SemiG.A == W, Mon : Monad, Mon.F == F, A == (AA) -> B {
        return flatMap({ pair in fa.map(pair, monad)}, semigroup, monad)
    }
    
    public func flatMap<B, SemiG, Mon>(_ f : @escaping (A) -> WriterT<F, W, B>, _ semigroup : SemiG, _ monad : Mon) -> WriterT<F, W, B> where SemiG : Semigroup, SemiG.A == W, Mon : Monad, Mon.F == F {
        return WriterT<F, W, B>(monad.flatMap(value, { pair in monad.map(f(pair.1).value, { pair2 in (semigroup.combine(pair.0, pair2.0), pair2.1) }) }))
    }
    
    public func semiflatMap<B, SemiG, Mon>(_ f : @escaping (A) -> Kind<F, B>, _ semigroup : SemiG, _ monad : Mon) -> WriterT<F, W, B> where SemiG : Semigroup, SemiG.A == W, Mon : Monad, Mon.F == F {
        return flatMap({ a in self.liftF(f(a), monad) }, semigroup, monad)
    }
    
    public func subflatMap<B, Mon>(_ f : @escaping (A) -> (W, B), _ monad : Mon) -> WriterT<F, W, B> where Mon : Monad, Mon.F == F {
        return transform({ pair in f(pair.1) }, monad)
    }
    
    public func transform<B, U, Mon>(_ f : @escaping ((W, A)) -> (U, B), _ monad : Mon) -> WriterT<F, U, B> where Mon : Monad, Mon.F == F {
        return WriterT<F, U, B>(monad.flatMap(value, { pair in monad.pure(f(pair)) }))
    }
    
    public func swap<Mon>(_ monad : Mon) -> WriterT<F, A, W> where Mon : Monad, Mon.F == F {
        return transform({ pair in (pair.1, pair.0) }, monad)
    }
    
    public func combineK<SemiGK>(_ y : WriterT<F, W, A>, _ semigroupK : SemiGK) -> WriterT<F, W, A> where SemiGK : SemigroupK, SemiGK.F == F {
        return WriterT(semigroupK.combineK(value, y.value))
    }
    
    public func tell<SemiG, Mon>(_ w : W, _ semigroup : SemiG, _ monad : Mon) -> WriterT<F, W, A> where SemiG : Semigroup, SemiG.A == W, Mon : Monad, Mon.F == F {
        return mapAcc({ inW in semigroup.combine(inW, w) }, monad)
    }
    
    public func listen<Mon>(_ monad : Mon) -> Kind<WriterTPartial<F, W>, (W, A)> where Mon : Monad, Mon.F == F {
        return WriterT<F, W, (W, A)>(monad.flatMap(content(monad), { a in monad.map(self.write(monad), { l in (l, (l, a)) }) }))
    }
    
    public func content<Func>(_ functor : Func) -> Kind<F, A> where Func : Functor, Func.F == F {
        return functor.map(value, { pair in pair.1 })
    }
    
    public func write<Func>(_ functor : Func) -> Kind<F, W> where Func : Functor, Func.F == F {
        return functor.map(value, { pair in pair.0 })
    }
    
    public func reset<Mono, Mon>(_ monoid : Mono, _ monad : Mon) -> WriterT<F, W, A> where Mono : Monoid, Mono.A == W, Mon : Monad, Mon.F == F {
        return mapAcc(constant(monoid.empty), monad)
    }
}

public extension WriterT {
    public static func functor<FuncF>(_ functor : FuncF) -> FunctorInstance<F, W, FuncF> {
        return FunctorInstance<F, W, FuncF>(functor)
    }
    
    public static func applicative<MonF, MonoW>(_ monad : MonF, _ monoid : MonoW) -> ApplicativeInstance<F, W, MonF, MonoW> {
        return ApplicativeInstance<F, W, MonF, MonoW>(monad, monoid)
    }
    
    public static func monad<MonF, MonoW>(_ monad : MonF, _ monoid : MonoW) -> MonadInstance<F, W, MonF, MonoW> {
        return MonadInstance<F, W, MonF, MonoW>(monad, monoid)
    }
    
    public static func monadFilter<MonFilF, MonoW>(_ monad : MonFilF, _ monoid : MonoW) -> MonadFilterInstance<F, W, MonFilF, MonoW> {
        return MonadFilterInstance<F, W, MonFilF, MonoW>(monad, monoid)
    }
    
    public static func semigroupK<SemiKF>(_ semigroupK : SemiKF) -> SemigroupKInstance<F, W, SemiKF> {
        return SemigroupKInstance<F, W, SemiKF>(semigroupK)
    }

    public static func monoidK<MonoKF>(_ monoidK : MonoKF) -> MonoidKInstance<F, W, MonoKF> {
        return MonoidKInstance<F, W, MonoKF>(monoidK)
    }
    
    public static func writer<MonF, MonoW>(_ monad : MonF, _ monoid : MonoW) -> MonadWriterInstance<F, W, MonF, MonoW> {
        return MonadWriterInstance<F, W, MonF, MonoW>(monad, monoid)
    }
    
    public static func eq<EqF>(_ eq : EqF) -> EqInstance<F, W, A, EqF> {
        return EqInstance<F, W, A, EqF>(eq)
    }

    public class FunctorInstance<G, W, FuncG> : Functor where FuncG : Functor, FuncG.F == G {
        public typealias F = WriterTPartial<G, W>
        
        private let functor : FuncG
        
        init(_ functor : FuncG) {
            self.functor = functor
        }
        
        public func map<A, B>(_ fa: WriterTOf<G, W, A>, _ f: @escaping (A) -> B) -> WriterTOf<G, W, B> {
            return WriterT<G, W, A>.fix(fa).map(f, functor)
        }
    }

    public class ApplicativeInstance<G, W, MonG, MonoW> : FunctorInstance<G, W, MonG>, Applicative where MonG : Monad, MonG.F == G, MonoW : Monoid, MonoW.A == W {
        
        fileprivate let monad : MonG
        fileprivate let monoid : MonoW
        
        init(_ monad : MonG, _ monoid : MonoW) {
            self.monad = monad
            self.monoid = monoid
            super.init(monad)
        }
        
        public func pure<A>(_ a: A) -> WriterTOf<G, W, A> {
            return WriterT<G, W, A>(monad.pure((monoid.empty, a)))
        }
        
        public func ap<A, B>(_ ff: WriterTOf<G, W, (A) -> B>, _ fa: WriterTOf<G, W, A>) -> WriterTOf<G, W, B> {
            return WriterT<G, W, (A) -> B>.fix(ff).ap(WriterT<G, W, A>.fix(fa), monoid, monad)
        }
    }

    public class MonadInstance<G, W, MonG, MonoW> : ApplicativeInstance<G, W, MonG, MonoW>, Monad where MonG : Monad, MonG.F == G, MonoW : Monoid, MonoW.A == W {
        
        public func flatMap<A, B>(_ fa: WriterTOf<G, W, A>, _ f: @escaping (A) -> WriterTOf<G, W, B>) -> WriterTOf<G, W, B> {
            return WriterT<G, W, A>.fix(fa).flatMap({ a in WriterT<G, W, B>.fix(f(a)) }, monoid, monad)
        }
        
        public func tailRecM<A, B>(_ a: A, _ f: @escaping (A) -> WriterTOf<G, W, Either<A, B>>) -> WriterTOf<G, W, B> {
            return WriterT<G, W, A>.tailRecM(a, f, monad)
        }
    }

    public class MonadFilterInstance<G, W, MonFilG, MonoW> : MonadInstance<G, W, MonFilG, MonoW>, MonadFilter where MonFilG : MonadFilter, MonFilG.F == G, MonoW : Monoid, MonoW.A == W {

        private let monadFilter : MonFilG
        
        override init(_ monadFilter : MonFilG, _ monoid : MonoW) {
            self.monadFilter = monadFilter
            super.init(monadFilter, monoid)
        }
        
        public func empty<A>() -> WriterTOf<G, W, A> {
            return WriterT<G, W, A>(monadFilter.empty())
        }
    }

    public class SemigroupKInstance<G, W, SemiKG> : SemigroupK where SemiKG : SemigroupK, SemiKG.F == G {
        public typealias F = WriterTPartial<G, W>
        
        private let semigroupK : SemiKG
        
        init(_ semigroupK : SemiKG) {
            self.semigroupK = semigroupK
        }
        
        public func combineK<A>(_ x: WriterTOf<G, W, A>, _ y: WriterTOf<G, W, A>) -> WriterTOf<G, W, A> {
            return WriterT<G, W, A>.fix(x).combineK(WriterT<G, W, A>.fix(y), semigroupK)
        }
    }

    public class MonoidKInstance<G, W, MonoKG> : SemigroupKInstance<G, W, MonoKG>, MonoidK where MonoKG : MonoidK, MonoKG.F == G {
        
        private let monoidK : MonoKG
        
        override init(_ monoidK : MonoKG) {
            self.monoidK = monoidK
            super.init(monoidK)
        }
        
        public func emptyK<A>() -> WriterTOf<G, W, A> {
            return WriterT<G, W, A>(monoidK.emptyK())
        }
    }

    public class MonadWriterInstance<G, V, MonG, MonoW> : MonadInstance<G, V, MonG, MonoW>, MonadWriter where MonG : Monad, MonG.F == G, MonoW : Monoid, MonoW.A == V {
        public typealias W = V
        
        public func writer<A>(_ aw: (V, A)) -> WriterTOf<G, V, A> {
            return WriterT<G, V, A>.put2(aw.1, aw.0, monad)
        }
        
        public func listen<A>(_ fa: WriterTOf<G, V, A>) -> WriterTOf<G, V, (V, A)> {
            return WriterT<G, V, (V, A)>(monad.flatMap(WriterT<G, V, A>.fix(fa).content(self.monad), { a in
                self.monad.map(WriterT<G, V, A>.fix(fa).write(self.monad), { l in
                    (l, (l, a))
                })
            }))
        }
        
        public func pass<A>(_ fa: WriterTOf<G, V, ((V) -> V, A)>) -> WriterTOf<G, V, A> {
            return WriterT<G, V, A>.pass(WriterT<G, V, ((V) -> V, A)>.fix(fa), monad)
        }
    }

    public class EqInstance<F, W, B, EqF> : Eq where EqF : Eq, EqF.A == Kind<F, (W, B)> {
        public typealias A = WriterTOf<F, W, B>
        
        private let eq : EqF
        
        init(_ eq : EqF) {
            self.eq = eq
        }
        
        public func eqv(_ a: WriterTOf<F, W, B>, _ b: WriterTOf<F, W, B>) -> Bool {
            let a = WriterT<F, W, B>.fix(a)
            let b = WriterT<F, W, B>.fix(b)
            return eq.eqv(a.value, b.value)
        }
    }
}