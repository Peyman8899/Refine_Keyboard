import UIKit

/// Enlarged character "callout" bubble shown above a key while it is pressed,
/// mimicking the iOS system keyboard's key preview.
final class KeyPreviewView: UIView {
    private let label = UILabel()

    var keyFillColor: UIColor = .white {
        didSet { backgroundColor = keyFillColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isHidden = true
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2

        label.textAlignment = .center
        label.font = .systemFont(ofSize: 28, weight: .regular)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the bubble centered above `keyFrame` (in the coordinate space of `containerView`),
    /// sized to comfortably enclose a single enlarged character.
    func show(character: String, above keyFrame: CGRect, in containerView: UIView) {
        label.text = character

        // Cover the pressed key and extend upward like the native iOS callout.
        let width = max(keyFrame.width + 8, 44)
        let height = keyFrame.height + 38
        let unclampedX = keyFrame.midX - width / 2
        let x = min(max(unclampedX, 4), max(4, containerView.bounds.width - width - 4))
        let y = keyFrame.minY - 38

        frame = CGRect(x: x, y: y, width: width, height: height)
        containerView.bringSubviewToFront(self)
        isHidden = false
    }

    func hide() {
        isHidden = true
    }
}
