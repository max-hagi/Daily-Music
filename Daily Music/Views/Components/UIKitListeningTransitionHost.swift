//
//  UIKitListeningTransitionHost.swift
//  Daily Music
//
//  Hosts ListeningView in a child UIHostingController so UIKit can animate one
//  already-laid-out layer. SwiftUI owns only the presentation intent; UIKit owns
//  preparation, motion, readiness, and teardown ordering.
//

import SwiftUI
import UIKit

struct UIKitListeningTransitionHost<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let reduceMotion: Bool
    let onDismissed: () -> Void
    @ViewBuilder let content: (_ isReady: Bool) -> Content

    func makeUIViewController(context: Context) -> ListeningTransitionContainerController<Content> {
        ListeningTransitionContainerController(
            reduceMotion: reduceMotion,
            onDismissed: onDismissed,
            content: content
        )
    }

    func updateUIViewController(
        _ controller: ListeningTransitionContainerController<Content>,
        context: Context
    ) {
        controller.update(
            wantsPresentation: isPresented,
            reduceMotion: reduceMotion,
            onDismissed: onDismissed,
            content: content
        )
    }

    static func dismantleUIViewController(
        _ controller: ListeningTransitionContainerController<Content>,
        coordinator: Void
    ) {
        controller.cancelAndDetach()
    }
}

@MainActor
final class ListeningTransitionContainerController<Content: View>: UIViewController {
    private var machine = ListeningHostMachine()
    private var hostingController: UIHostingController<Content>?
    private var animator: UIViewPropertyAnimator?
    private var wantsPresentation = false
    private var reduceMotion: Bool
    private var onDismissed: () -> Void
    private var content: (Bool) -> Content

    init(
        reduceMotion: Bool,
        onDismissed: @escaping () -> Void,
        content: @escaping (Bool) -> Content
    ) {
        self.reduceMotion = reduceMotion
        self.onDismissed = onDismissed
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = PassthroughTransitionContainerView()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reconcilePresentation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hostingController?.view.frame = view.bounds
        reconcilePresentation()
    }

    func update(
        wantsPresentation: Bool,
        reduceMotion: Bool,
        onDismissed: @escaping () -> Void,
        content: @escaping (Bool) -> Content
    ) {
        self.wantsPresentation = wantsPresentation
        self.reduceMotion = reduceMotion
        self.onDismissed = onDismissed
        self.content = content
        reconcilePresentation()
    }

    func cancelAndDetach() {
        animator?.stopAnimation(true)
        animator = nil
        _ = machine.handle(.cancelled)
        detachHost(notify: false)
    }
}

private final class PassthroughTransitionContainerView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        subviews.contains {
            !$0.isHidden && $0.alpha > 0.01 && $0.frame.contains(point)
        }
    }
}

private extension ListeningTransitionContainerController {
    func reconcilePresentation() {
        guard isViewLoaded, view.window != nil, view.bounds.height > 1 else { return }

        if wantsPresentation {
            guard machine.handle(.presentRequested) == .prepareHost else { return }
            prepareHost()
        } else {
            guard machine.handle(.dismissRequested) == .animateOut else { return }
            refreshContent()
            animateOut()
        }
    }

    func prepareHost() {
        let hosting = UIHostingController(rootView: content(false))
        hosting.view.backgroundColor = .black

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.didMove(toParent: self)
        view.layoutIfNeeded()

        hosting.view.transform = reduceMotion
            ? .identity
            : CGAffineTransform(translationX: 0, y: -view.bounds.height)
        hosting.view.alpha = reduceMotion ? 0 : 1
        hostingController = hosting

        guard machine.handle(.hostPrepared) == .animateIn else { return }
        animateIn()
    }

    func animateIn() {
        guard let hostedView = hostingController?.view else { return }

        let animator = makeAnimator {
            hostedView.transform = .identity
            hostedView.alpha = 1
        }
        self.animator = animator
        animator.addCompletion { [weak self] position in
            guard let self, position == .end else { return }
            self.animator = nil
            _ = self.machine.handle(.presentationCompleted)
            self.refreshContent()
            UIAccessibility.post(
                notification: .screenChanged,
                argument: self.hostingController?.view
            )
            self.reconcilePresentation()
        }
        animator.startAnimation()
    }

    func animateOut() {
        guard let hostedView = hostingController?.view else {
            finishDismissal()
            return
        }

        let height = view.bounds.height
        let animator = makeAnimator {
            if self.reduceMotion {
                hostedView.alpha = 0
            } else {
                hostedView.transform = CGAffineTransform(translationX: 0, y: -height)
            }
        }
        self.animator = animator
        animator.addCompletion { [weak self] position in
            guard let self, position == .end else { return }
            self.animator = nil
            self.finishDismissal()
        }
        animator.startAnimation()
    }

    func makeAnimator(animations: @escaping () -> Void) -> UIViewPropertyAnimator {
        if reduceMotion {
            return UIViewPropertyAnimator(
                duration: 0.16,
                curve: .easeInOut,
                animations: animations
            )
        }

        return UIViewPropertyAnimator(
            duration: 0.48,
            dampingRatio: 0.88,
            animations: animations
        )
    }

    func refreshContent() {
        hostingController?.rootView = content(machine.isReady)
    }

    func finishDismissal() {
        guard machine.handle(.dismissalCompleted) == .detachHost else { return }
        detachHost(notify: true)
    }

    func detachHost(notify: Bool) {
        guard let hosting = hostingController else { return }

        hosting.willMove(toParent: nil)
        hosting.view.removeFromSuperview()
        hosting.removeFromParent()
        hostingController = nil

        if notify {
            onDismissed()
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }
}
