//
//  EditLabelView.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Dependencies
import SQLiteData
import SwiftUI

@MainActor
struct EditLabelView: View {
    @Dependency(\.defaultDatabase) var database
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: Router

    let labelID: UUID?
    var presentedInSheet: Bool
    var onDismiss: (() -> Void)?
    var onLabelCreated: ((SQLiteInventoryLabel) -> Void)?

    // Form state
    @State private var labelName = ""
    @State private var labelDesc = ""
    @State private var labelColor = Color.red
    @State private var labelEmoji = "🏷️"
    @State private var isEditing = false
    @State private var showEmojiPicker = false

    init(
        labelID: UUID? = nil, isEditing: Bool = false, presentedInSheet: Bool = false,
        onDismiss: (() -> Void)? = nil,
        onLabelCreated: ((SQLiteInventoryLabel) -> Void)? = nil
    ) {
        self.labelID = labelID
        self._isEditing = State(initialValue: isEditing)
        self.presentedInSheet = presentedInSheet
        self.onDismiss = onDismiss
        self.onLabelCreated = onLabelCreated
    }

    // Computed properties
    private var isNewLabel: Bool {
        labelID == nil
    }

    private var isEditingEnabled: Bool {
        isNewLabel || isEditing
    }

    var body: some View {
        Form {
            Section("Details") {
                FormTextFieldRow(
                    label: "Name", text: $labelName, isEditing: $isEditing, placeholder: "Electronics",
                    textFieldIdentifier: "label-name-field"
                )
                .disabled(!isEditingEnabled)
                ColorPicker("Color", selection: $labelColor, supportsOpacity: false)
                    .disabled(!isEditingEnabled)
                HStack {
                    Text("Emoji")
                        .frame(width: 100, alignment: .leading)
                    Spacer()
                    Button(action: {
                        if isEditingEnabled {
                            showEmojiPicker = true
                        }
                    }) {
                        Text(labelEmoji)
                            .font(.system(size: 32))
                            .frame(width: 50, height: 40)
                            .background(isEditingEnabled ? Color.gray.opacity(0.2) : Color.clear)
                            .clipShape(.rect(cornerRadius: UIConstants.cornerRadius))
                    }
                    .disabled(!isEditingEnabled)
                    .sheet(isPresented: $showEmojiPicker) {
                        EmojiPickerView(selectedEmoji: $labelEmoji)
                    }
                }

            }
            if isEditingEnabled || !labelDesc.isEmpty {
                Section("Description") {
                    TextEditor(text: $labelDesc)
                        .disabled(!isEditingEnabled)
                        .foregroundStyle(isEditingEnabled ? .primary : .secondary)
                        .frame(height: 100)
                }
            }
        }
        .navigationTitle(isNewLabel ? "New Label" : "Edit \(labelName.isEmpty ? "Label" : labelName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presentedInSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("label-dismiss-button")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if !isNewLabel {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveExistingLabel()
                            isEditing = false
                            if presentedInSheet {
                                dismissView()
                            }
                        } else {
                            isEditing = true
                        }
                    }
                    .accessibilityIdentifier("label-edit-save-button")
                } else {
                    Button("Save") {
                        saveNewLabel()
                        dismissView()
                    }
                    .disabled(labelName.isEmpty)
                    .bold()
                    .accessibilityIdentifier("label-save-button")
                }
            }
        }
        .task(id: labelID) {
            await loadLabelData()
        }
    }

    private func loadLabelData() async {
        guard let labelID = labelID else { return }
        do {
            guard
                let label = try await database.read({ db in
                    try SQLiteInventoryLabel.find(labelID).fetchOne(db)
                })
            else { return }

            labelName = label.name
            labelDesc = label.desc
            labelColor = Color(label.color ?? .red)
            labelEmoji = label.emoji
        } catch {
            print("Failed to load label: \(error)")
        }
    }

    private func saveExistingLabel() {
        guard let labelID = labelID else { return }
        let name = labelName
        let desc = labelDesc
        let color = UIColor(labelColor)
        let emoji = labelEmoji
        do {
            try database.write { db in
                try SQLiteInventoryLabel.find(labelID)
                    .update {
                        $0.name = name
                        $0.desc = desc
                        $0.color = color
                        $0.emoji = emoji
                    }
                    .execute(db)
            }
        } catch {
            print("Failed to save label: \(error)")
        }
    }

    private func saveNewLabel() {
        let newID = UUID()
        let name = labelName
        let desc = labelDesc
        let color = UIColor(labelColor)
        let emoji = labelEmoji
        do {
            try database.write { db in
                try SQLiteInventoryLabel.insert {
                    SQLiteInventoryLabel(
                        id: newID,
                        name: name,
                        desc: desc,
                        color: color,
                        emoji: emoji
                    )
                }.execute(db)
            }
            let newLabel = SQLiteInventoryLabel(
                id: newID, name: name, desc: desc, color: color, emoji: emoji
            )
            TelemetryManager.shared.trackLabelCreated(name: name)
            print("EditLabelView: Created new label - \(name)")
            onLabelCreated?(newLabel)
        } catch {
            print("Failed to create label: \(error)")
        }
    }

    private func dismissView() {
        if presentedInSheet {
            onDismiss?()
            dismiss()
        } else {
            router.navigateBack()
        }
    }
}

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) private var dismiss

    // Most common emoji categories
    let emojiCategories: [(String, [String])] = [
        (
            "Smileys",
            [
                "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋",
                "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🤩", "🥳", "🫠", "🫡", "🫢", "🫣", "🫤", "🫥", "🫨", "🫩", "🙂‍↔️", "🙂‍↕️",
            ]
        ),
        (
            "Objects",
            [
                "📱", "💻", "⌨️", "🖥️", "🖱️", "🖨️", "📷", "📸", "📹", "🎥", "📽️", "🎞️", "📞", "☎️", "📟", "📠", "📺", "📻", "🎙️", "🎚️", "🎛️",
                "🧭", "⏱️", "⏲️", "⏰", "🕰️", "⌚️", "📡", "🔋", "🪫", "🔌", "💡", "🔦", "🕯️", "🧯", "🛢️", "💸", "💵", "💴", "💶", "💷", "💰",
                "💳",
                "💎", "⚖️", "🧰", "🔧", "🔨", "⚒️", "🛠️", "⛏️", "🔩", "⚙️", "🧱", "⛓️", "⛓️‍💥", "🧲", "🔫", "💣", "🧨", "🪓", "🔪", "🗡️", "⚔️",
                "🛡️",
                "🚬", "⚰️", "⚱️", "🏺", "🔮", "📿", "🧿", "🪬", "💈", "⚗️", "🔭", "🔬", "🕳️", "💊", "💉", "🩸", "🩹", "🩺", "🚪", "🛏️", "🛋️",
                "🪑",
                "🚽", "🚿", "🛁", "🧴", "🧷", "🧹", "🧺", "🧻", "🧼", "🧽", "🧯", "🪤", "🫙", "🛝", "🛞", "🛟", "🛜", "🪭", "🪮", "🫆", "🪏",
                "🫟",
                "🚫", "❌", "⭕", "♨️", "🚹", "🚺", "🚻", "🚼", "🚾", "🛂", "🛃", "🛄", "🛅", "🚸", "📵", "🔞", "☢️", "☣️",
            ]
        ),
        (
            "Animals",
            [
                "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🙈", "🙉", "🙊", "🐔", "🐧", "🐦",
                "🐤", "🦆", "🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🐛", "🦋", "🐌", "🐞", "🐜", "🦟", "🦗", "🕷️", "🕸️", "🦂", "🐢",
                "🐍", "🦎", "🦖", "🦕", "🐙", "🦑", "🦐", "🦞", "🦀", "🐡", "🐠", "🐟", "🐬", "🐳", "🐋", "🦈", "🐊", "🐅", "🐆", "🦓", "🦍",
                "🦧", "🐘", "🦛", "🦏", "🐪", "🐫", "🦒", "🦘", "🐃", "🐂", "🐄", "🐎", "🐖", "🐏", "🐑", "🦙", "🐐", "🦌", "🐕", "🐩", "🦮",
                "🐕‍🦺", "🐈", "🐓", "🦃", "🦚", "🦜", "🦢", "🦩", "🕊️", "🐇", "🦝", "🦨", "🦡", "🦦", "🦥", "🐁", "🐀", "🐿️", "🦔", "🧌",
                "🪹", "🪺", "🫎", "🫏", "🪿", "🪼", "🐦‍🔥",
            ]
        ),
        (
            "Food",
            [
                "🍏", "🍎", "🍐", "🍊", "🍋", "🍋‍🟩", "🍌", "🍉", "🍇", "🍓", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦",
                "🥬",
                "🥒", "🌶️", "🌽", "🥕", "🧄", "🧅", "🥔", "🍠", "🫚", "🫛", "🫜", "🥐", "🥯", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳", "🧈", "🥞",
                "🧇", "🥓", "🥩",
                "🍗", "🍖", "🦴", "🌭", "🍔", "🍟", "🍕", "🥪", "🥙", "🧆", "🌮", "🌯", "🫔", "🥗", "🥘", "🥫", "🍝", "🍜", "🍲", "🍛", "🍣",
                "🍱",
                "🥟", "🦪", "🍤", "🍙", "🍚", "🍘", "🍥", "🥠", "🥮", "🍢", "🍡", "🍧", "🍨", "🍦", "🥧", "🧁", "🍰", "🎂", "🍮", "🍭", "🍬",
                "🍫", "🍿", "🍩", "🍪", "🌰", "🥜", "🍯", "🫘", "🍄‍🟫", "🥛", "🍼", "☕", "🍵", "🧃", "🥤", "🍶", "🍺", "🍻", "🥂", "🍷", "🥃",
                "🍸", "🍹",
                "🧉", "🍾", "🧊", "🫗", "🥄", "🍴", "🍽️", "🥣", "🥡", "🥢",
            ]
        ),
        (
            "Activity",
            [
                "⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱", "🪀", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏", "🥅", "⛳", "🪁", "🏹",
                "🎣", "🤿", "🥊", "🥋", "🎽", "🛹", "🛼", "🛷", "⛸️", "🥌", "🎿", "⛷️", "🏂", "🪂", "🏋️", "🏋️‍♀️", "🏋️‍♂️", "🤼", "🤼‍♀️", "🤼‍♂️", "🤸",
                "🤸‍♀️", "🤸‍♂️", "⛹️", "⛹️‍♀️", "⛹️‍♂️", "🤺", "🤾", "🤾‍♀️", "🤾‍♂️", "🏌️", "🏌️‍♀️", "🏌️‍♂️", "🏇", "🧘", "🧘‍♀️", "🧘‍♂️", "🏄", "🏄‍♀️", "🏄‍♂️", "🏊", "🏊‍♀️",
                "🏊‍♂️", "🤽", "🤽‍♀️", "🤽‍♂️", "🚣", "🚣‍♀️", "🚣‍♂️", "🧗", "🧗‍♀️", "🧗‍♂️", "🚵", "🚵‍♀️", "🚵‍♂️", "🚴", "🚴‍♀️", "🚴‍♂️", "🏆", "🥇", "🥈", "🥉", "🏅",
                "🎖️", "🏵️", "🎗️", "🎫", "🎟️", "🎪", "🤹", "🤹‍♀️", "🤹‍♂️", "🎭", "🩰", "🎨", "🎬", "🎤", "🎧", "🎼", "🎹", "🥁", "🎷", "🎺", "🎸",
                "🪕", "🎻", "🪇", "🪈", "🪉", "🎲", "♟️", "🎯", "🎳", "🎮", "🎰", "🧩",
            ]
        ),
        (
            "Travel",
            [
                "🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "🚐", "🚚", "🚛", "🚜", "🦯", "🦽", "🦼", "🛴", "🚲", "🛵", "🏍️", "🛺",
                "🚨", "🚔", "🚍", "🚘", "🚖", "🚡", "🚠", "🚟", "🚃", "🚋", "🚞", "🚝", "🚄", "🚅", "🚈", "🚂", "🚆", "🚇", "🚊", "🚉", "✈️",
                "🛫", "🛬", "🛩️", "💺", "🛰️", "🚀", "🛸", "🚁", "🛶", "⛵", "🚤", "🛥️", "🛳️", "⛴️", "🚢", "⚓", "⛽", "🚧", "🚦", "🚥", "🚏",
                "🗺️", "🗿", "🗽", "🗼", "🏰", "🏯", "🏟️", "🎡", "🎢", "🎠", "⛲", "⛱️", "🏖️", "🏝️", "🏜️", "🌋", "⛰️", "🏔️", "🗻", "🏕️", "⛺",
                "🏠", "🏡", "🏘️", "🏚️", "🏗️", "🏢", "🏭", "🏬", "🏣", "🏤", "🏥", "🏦", "🏨", "🏪", "🏫", "🏩", "💒", "🏛️", "⛪", "🕌", "🕍",
                "🛕", "🕋", "⛩️", "🛤️", "🛣️", "🗾", "🎑", "🏞️", "🌅", "🌄", "🌠", "🎇", "🎆", "🌇", "🌆", "🏙️", "🌃", "🌌", "🌉", "🌁",
            ]
        ),
        (
            "Symbols",
            [
                "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "🩷", "🩵", "🩶", "💔", "❤️‍🔥", "💕", "💞", "💓", "💗", "💖", "💘", "💝",
                "⭐", "🌟", "✨",
                "💫", "🔥", "💯", "✅", "❎", "☑️", "⚠️", "🚫", "⛔", "❌", "⭕", "❓", "❗", "‼️", "⁉️", "🔴", "🟠", "🟡", "🟢", "🔵", "🟣",
                "🟤", "⚫", "⚪", "🔶", "🔷", "🔸", "🔹", "▪️", "▫️", "◼️", "◻️", "🔲", "🔳", "📌", "📍", "🏷️", "🔖", "📎", "🖇️", "✂️", "📐",
                "📏", "🔒", "🔓", "🔐", "🔑", "🗝️", "🔔", "🔕", "📦", "📬", "📮", "📤", "📥", "📨", "✉️", "📧", "🎁", "🛒", "♻️", "🆕", "🆓",
                "🆙", "🔝", "🔜", "🔛", "🔚", "➡️", "⬅️", "⬆️", "⬇️", "↗️", "↘️", "↙️", "↖️", "↩️", "↪️", "🔄", "🔃", "ℹ️", "Ⓜ️", "🅿️",
            ]
        ),
        (
            "Clothing",
            [
                "👕", "👖", "🧣", "🧤", "🧥", "🧦", "👗", "👘", "🥻", "🩱", "🩲", "🩳", "👙", "👚", "👛", "👜", "👝", "🛍️", "🎒", "👞", "👟",
                "🥾", "🥿", "👠", "👡", "🩴", "👢", "👑", "👒", "🎩", "🎓", "🧢", "⛑️", "💄", "💍", "💎", "👔", "🥼", "🦺", "👓", "🕶️", "🥽",
                "🩺", "🩹", "🩼", "🪖", "⌚", "🧳", "🌂", "☂️",
            ]
        ),
        (
            "Nature",
            [
                "🌸", "🌹", "🌺", "🌻", "🌼", "🌷", "🌱", "🌲", "🌳", "🌴", "🌵", "🪾", "🎋", "🎍", "🌾", "🌿", "☘️", "🍀", "🍁", "🍂", "🍃",
                "🍄",
                "🌰", "🪴", "🪵", "🪨", "💐", "🪻", "🪷", "🪸", "🪽", "☀️", "🌤️", "⛅", "🌥️", "☁️", "🌦️", "🌧️", "⛈️", "🌩️", "🌨️", "❄️", "☃️",
                "⛄", "🌬️",
                "💨", "🌊", "🌈", "🌪️", "🌫️", "💧", "💦", "☔", "⚡", "🌙", "🌛", "🌜", "🌚", "🌝", "🌞", "⭐", "🌟", "💫", "✨", "☄️",
            ]
        ),
        (
            "Gestures",
            [
                "👍", "👎", "👊", "✊", "🤛", "🤜", "👏", "🙌", "👐", "🤲", "🤝", "🙏", "✋", "🤚", "🖐️", "🖖", "👋", "🤙", "💪", "🦾", "✌️",
                "🤞", "🤟", "🤘", "🤌", "👌", "🤏", "👈", "👉", "👆", "👇", "☝️", "✍️", "🫶", "🫱", "🫲", "🫳", "🫴", "🫵", "🫰", "🫷", "🫸",
                "🫦", "🦵", "🦶", "🦿", "👂", "🦻", "👃", "👀", "👁️", "👅", "👄",
            ]
        ),
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(emojiCategories, id: \.0) { category in
                        VStack(alignment: .leading) {
                            Text(category.0)
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                                ForEach(category.1, id: \.self) { emoji in
                                    Button(action: {
                                        selectedEmoji = emoji
                                        dismiss()
                                    }) {
                                        Text(emoji)
                                            .font(.system(size: 28))
                                            .frame(width: 44, height: 44)
                                            .background(
                                                selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear
                                            )
                                            .clipShape(.rect(cornerRadius: 8))
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom)
                    }
                }
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    EditLabelView(isEditing: true, presentedInSheet: true)
        .environmentObject(Router())
}
