import UIKit

final class KeyboardViewController: UIInputViewController {
    private let client = RewriteClient()
    private var selectedMode: RewriteMode = .polish
    private var modeButtons: [RewriteMode: UIButton] = [:]
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboard()
    }

    private func setupKeyboard() {
        view.backgroundColor = UIColor.systemBackground

        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])

        statusLabel.text = "Ready"
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        root.addArrangedSubview(statusLabel)

        let modeRow = UIStackView()
        modeRow.axis = .horizontal
        modeRow.spacing = 6
        modeRow.distribution = .fillEqually
        RewriteMode.allCases.forEach { mode in
            let button = makeButton(title: mode.rawValue)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            button.addAction(UIAction { [weak self] _ in
                self?.selectedMode = mode
                self?.refreshModeButtons()
                self?.statusLabel.text = "\(mode.rawValue) selected"
            }, for: .touchUpInside)
            modeButtons[mode] = button
            modeRow.addArrangedSubview(button)
        }
        root.addArrangedSubview(modeRow)
        refreshModeButtons()

        let refineButton = makeButton(title: "Refine")
        refineButton.backgroundColor = .systemBlue
        refineButton.setTitleColor(.white, for: .normal)
        refineButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        refineButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        refineButton.addAction(UIAction { [weak self] _ in
            self?.refineCurrentText()
        }, for: .touchUpInside)
        root.addArrangedSubview(refineButton)

        ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"].forEach { rowText in
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 5
            row.distribution = .fillEqually
            rowText.forEach { character in
                let button = makeButton(title: String(character))
                button.addAction(UIAction { [weak self] _ in
                    self?.textDocumentProxy.insertText(String(character).lowercased())
                }, for: .touchUpInside)
                row.addArrangedSubview(button)
            }
            root.addArrangedSubview(row)
        }

        let commandRow = UIStackView()
        commandRow.axis = .horizontal
        commandRow.spacing = 6
        commandRow.distribution = .fill

        let nextKeyboard = makeButton(title: "Next")
        nextKeyboard.widthAnchor.constraint(equalToConstant: 48).isActive = true
        nextKeyboard.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        commandRow.addArrangedSubview(nextKeyboard)

        let space = makeButton(title: "space")
        space.addAction(UIAction { [weak self] _ in
            self?.textDocumentProxy.insertText(" ")
        }, for: .touchUpInside)
        commandRow.addArrangedSubview(space)

        let delete = makeButton(title: "Del")
        delete.widthAnchor.constraint(equalToConstant: 56).isActive = true
        delete.addAction(UIAction { [weak self] _ in
            self?.textDocumentProxy.deleteBackward()
        }, for: .touchUpInside)
        commandRow.addArrangedSubview(delete)

        let enter = makeButton(title: "return")
        enter.widthAnchor.constraint(equalToConstant: 74).isActive = true
        enter.addAction(UIAction { [weak self] _ in
            self?.textDocumentProxy.insertText("\n")
        }, for: .touchUpInside)
        commandRow.addArrangedSubview(enter)

        root.addArrangedSubview(commandRow)
    }

    private func makeButton(title: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = .secondarySystemBackground
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .medium

        let button = UIButton(configuration: configuration)
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return button
    }

    private func refreshModeButtons() {
        for (mode, button) in modeButtons {
            button.backgroundColor = mode == selectedMode ? .systemBlue : .secondarySystemBackground
            button.setTitleColor(mode == selectedMode ? .white : .label, for: .normal)
        }
    }

    private func refineCurrentText() {
        let text = (textDocumentProxy.documentContextBeforeInput ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            statusLabel.text = "Type a message first"
            return
        }

        statusLabel.text = "Refining..."

        Task { [weak self] in
            guard let self else { return }
            do {
                let refined = try await client.rewrite(text: text, mode: selectedMode)
                await MainActor.run {
                    if refined == text {
                        self.statusLabel.text = "No changes suggested"
                    } else {
                        self.replaceCurrentDraft(original: text, refined: refined)
                        self.statusLabel.text = "Inserted"
                    }
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.text = (error as? LocalizedError)?.errorDescription ?? "Could not refine"
                }
            }
        }
    }

    private func replaceCurrentDraft(original: String, refined: String) {
        guard !refined.isEmpty else { return }
        original.forEach { _ in
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(refined)
    }
}
