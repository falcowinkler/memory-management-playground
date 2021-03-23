/* Let's start with a simple example
 * We have a class network service
 * it does some work, then calls a completion closure
 * It also references some value stored in "self", the pointer to the instance of NetworkService
 * The request was executed on.
 */
import Foundation
class NetworkService {
    var myCompletionHandler: (() -> Void)?
    let foo = "foo"
    func loadData() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
            print("Wohoo completed the network request.")
            print("This is my favorite value: \(self.foo)")
        }
    }
    deinit {
        print("I am the network service1 and i just got deinitialized")
        print("---------------------------------------------------------------")
    }
}

/* As we can see in the following, the service get's deallocated *as soon as the closure completes*.
 * Why is that? shouldn't it be thrown out right away?
 */

var networkService: NetworkService? = NetworkService()
networkService?.loadData()
networkService = nil

/* It's because of Automatic reference counting. Swift only deinitializes a reference type once all references to it are gone
 * The closure /closes over/ self, thus keeping a reference to the instance of NetworkService.
 * Once the closure is called and executed (After 2 seconds), this reference is no longer needed.
 * Now both the reference networkService as well as the reference inside the closure are gone.
 * No one needs NetworkService anymore, and so it get's brutally discarded by ARC. What a sad fate.
 */

/*
 * Mostly that's what we do in our app. We do something and call a completion closure.
 */

/*
 * Now let's look at the cases where weak self is definately needed to avoid a retain cycle.
 * It's the same as before, but we keep a reference to the completion handler around.
 */

class NetworkService2 {
    var myCompletionHandler: (() -> Void)?
    let foo = "foo"
    func loadData() {
        myCompletionHandler = {
            print("Wohoo completed the network request.")
            print("This is my favorite value: \(self.foo)")
            print("----------------------------------------------------------------------------")
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: myCompletionHandler!)
    }
    deinit {
        print("I am the network service 2 and i just got deinitialized")
    }
}
// UNCOMMENT THIS
/* var networkService2: NetworkService2? = NetworkService2()
 networkService2?.loadData()
 networkService2 = nil */

/*
 * Oh no! the deinitializer was never called!
 * Why is that? Simple: an instance of NetworkService2 keep reference to a closure
 * that keeps a reference to the instance. A cycle!
 * Both hold on to each other in an eternal loving embrace, and the network service is thus granted immortality
 * (it never get's deallocated)
 * How do we fix that?
 */


class NetworkService3 {
    var myCompletionHandler: (() -> Void)?
    let foo = "foo"
    func loadData() {
        myCompletionHandler = { [weak self] in
            guard let `self` = self else { return }
            print("Wohoo completed the network request.")
            print("This is my favorite value: \(self.foo)")
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: myCompletionHandler!)
    }
    deinit {
        print("I am the network service 3 and i just got deinitialized")
        print("-----------------------------------------------------------------------------")
    }
}
/*
 var networkService3: NetworkService3? = NetworkService3()
 networkService3?.loadData()
 networkService3 = nil
 */

/*
 * We use weak self. That tells ARC to still dealocate the object even when this refence from within the closure
 * is still existing.
 * We can also see that the closure is not even executed. So we learn, that using weak self without knowing what it does
 * can also be dangerous. If there is a closure that always must be executed, say a logging request or push registration
 * weak self can cause it to abort, if the object that initiated the request get's deallocated!
 */


/*
 * To summarize:
 * - Check if your closure captures a reference that introduces a reference cycle (see bonus content for another example), if so, break the cycle and use weak self, or refactor the code.
 * - If your closure should be aborted, as soon as the references held in the closure get removed (usually that's just self), use weak self
 * - in all other cases, don't use it! It is unnecessarry and confuses the programmer that knows about `weak self`.
 */


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Bonus content

/* Keep in mind this retain cycle thing is not just for when you retain the closure in your own class.
 * Let's look at this slightly more tricky example.
 * You have a very non-suspicious AppleSauceService that makes apple sauce.
 * It has a function execute that takes a closure, executes that closure, and then prints something.
 * It can also retry the last executed work.
 */

class AppleSauceService {
    private var lastExecutedWork: (() -> Void)?

    func retryLast() {
        lastExecutedWork!()
    }
    // Notice how stored closures are automatically escaping.
    func execute(work: @escaping (() -> Void)) {
        self.lastExecutedWork = work
        work()
        print("completed work in apple sauce service")
    }
}

/* Suspecting nothing,
 * The network service passes a closure to the apple sauce service, that also references a property of the
 * apple sauce service.
 * Exercise: draw/explain the retain cycle!
 */
class NetworkService4 {
    let foo = "foo"
    let appleSauceService = AppleSauceService()
    func loadData() {
        let aCompletionHandler = {
            print("Wohoo completed the network request.")
            print("Now i can make apple sauce with \(self.foo)")
            print("----------------------------------------------------------")
        }
        appleSauceService.execute(work: aCompletionHandler)
    }
    deinit {
        print("I am the network service 4 and i just got deinitialized")
    }
}

/*
 var networkService4: NetworkService4? = NetworkService4()
 networkService4?.loadData()
 networkService4 = nil
 */
