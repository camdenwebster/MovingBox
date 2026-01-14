//
//  EditLabelView.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import SwiftData
import SwiftUI

struct EditLabelView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @EnvironmentObject var settingsManager: SettingsManager
    var label: InventoryLabel?
    @State private var labelName = ""
    @State private var labelDesc = ""
    @State private var labelColor = Color.red
    @State private var labelEmoji = "🏷️"
    @State private var isEditing = false
    @State private var showEmojiPicker = false
    @Query(sort: [
        SortDescriptor(\InventoryLabel.name)
    ]) var labels: [InventoryLabel]
    @Query(sort: \Home.purchaseDate) private var homes: [Home]

    private var activeHome: Home? {
        guard let activeIdString = settingsManager.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    // MARK: - Add initializer to accept isEditing parameter
    init(label: InventoryLabel? = nil, isEditing: Bool = false) {
        self.label = label
        self._isEditing = State(initialValue: isEditing)
    }

    // Computed properties
    private var isNewLabel: Bool {
        label == nil
    }

    private var isEditingEnabled: Bool {
        isNewLabel || isEditing
    }

    var body: some View {
        Form {
            Section("Details") {
                FormTextFieldRow(label: "Name", text: $labelName, isEditing: $isEditing, placeholder: "Electronics")
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
                            .cornerRadius(UIConstants.cornerRadius)
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
                        .foregroundColor(isEditingEnabled ? .primary : .secondary)
                        .frame(height: 100)
                }
            }
        }
        .navigationTitle(isNewLabel ? "New Label" : "\(label?.name ?? "") Details")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: labelColor, setColor)
        .toolbar {
            if !isNewLabel {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        label?.name = labelName
                        label?.desc = labelDesc
                        label?.color = UIColor(labelColor)
                        label?.emoji = labelEmoji
                        isEditing = false
                    } else {
                        isEditing = true
                    }
                }
            } else {
                Button("Save") {
                    let newLabel = InventoryLabel(
                        name: labelName, desc: labelDesc, color: UIColor(labelColor), emoji: labelEmoji)

                    // Assign active home to new label
                    newLabel.home = activeHome

                    modelContext.insert(newLabel)
                    TelemetryManager.shared.trackLabelCreated(name: newLabel.name)
                    print("EditLabelView: Created new label - \(newLabel.name)")
                    print("EditLabelView: Assigned to home - \(activeHome?.name ?? "nil")")
                    print("EditLabelView: Total number of labels after save: \(labels.count)")
                    isEditing = false
                    router.navigateBack()
                }
                .disabled(labelName.isEmpty)
                .bold()
            }
        }
        .onAppear {
            if let existingLabel = label {
                // Initialize editing fields with existing values
                labelName = existingLabel.name
                labelDesc = existingLabel.desc
                labelColor = Color(existingLabel.color ?? .red)
                labelEmoji = existingLabel.emoji
            }
        }
    }

    func setColor() {

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
                "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🤩", "🥳",
            ]
        ),
        (
            "Objects",
            [
                "📱", "💻", "⌨️", "🖥️", "🖱️", "🖨️", "📷", "📸", "📹", "🎥", "📽️", "🎞️", "📞", "☎️", "📟", "📠", "📺", "📻", "🎙️", "🎚️", "🎛️",
                "🧭", "⏱️", "⏲️", "⏰", "🕰️", "⌚️", "📡", "🔋", "🔌", "💡", "🔦", "🕯️", "🧯", "🛢️", "💸", "💵", "💴", "💶", "💷", "💰", "💳",
                "💎", "⚖️", "🧰", "🔧", "🔨", "⚒️", "🛠️", "⛏️", "🔩", "⚙️", "🧱", "⛓️", "🧲", "🔫", "💣", "🧨", "🪓", "🔪", "🗡️", "⚔️", "🛡️",
                "🚬", "⚰️", "⚱️", "🏺", "🔮", "📿", "🧿", "💈", "⚗️", "🔭", "🔬", "🕳️", "💊", "💉", "🩸", "🩹", "🩺", "🚪", "🛏️", "🛋️", "🪑",
                "🚽", "🚿", "🛁", "🧴", "🧷", "🧹", "🧺", "🧻", "🧼", "🧽", "🧯", "🚫", "❌", "⭕", "♨️", "🚹", "🚺", "🚻", "🚼", "🚾", "🛂",
                "🛃", "🛄", "🛅", "🚸", "📵", "🔞", "☢️", "☣️",
            ]
        ),
        (
            "Animals",
            [
                "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🙈", "🙉", "🙊", "🐔", "🐧", "🐦",
                "🐤", "🦆", "🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🐛", "🦋", "🐌", "🐞", "🐜", "🦟", "🦗", "🕷️", "🕸️", "🦂", "🐢",
                "🐍", "🦎", "🦖", "🦕", "🐙", "🦑", "🦐", "🦞", "🦀", "🐡", "🐠", "🐟", "🐬", "🐳", "🐋", "🦈", "🐊", "🐅", "🐆", "🦓", "🦍",
                "🦧", "🐘", "🦛", "🦏", "🐪", "🐫", "🦒", "🦘", "🐃", "🐂", "🐄", "🐎", "🐖", "🐏", "🐑", "🦙", "🐐", "🦌", "🐕", "🐩", "🦮",
                "🐕‍🦺", "🐈", "🐓", "🦃", "🦚", "🦜", "🦢", "🦩", "🕊️", "🐇", "🦝", "🦨", "🦡", "🦦", "🦥", "🐁", "🐀", "🐿️", "🦔",
            ]
        ),
        (
            "Food",
            [
                "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬",
                "🥒", "🌶️", "🌽", "🥕", "🧄", "🧅", "🥔", "🍠", "🥐", "🥯", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳", "🧈", "🥞", "🧇", "🥓", "🥩",
                "🍗", "🍖", "🦴", "🌭", "🍔", "🍟", "🍕", "🥪", "🥙", "🧆", "🌮", "🌯", "🥗", "🥘", "🥫", "🍝", "🍜", "🍲", "🍛", "🍣", "🍱",
                "🥟", "🦪", "🍤", "🍙", "🍚", "🍘", "🍥", "🥠", "🥮", "🍢", "🍡", "🍧", "🍨", "🍦", "🥧", "🧁", "🍰", "🎂", "🍮", "🍭", "🍬",
                "🍫", "🍿", "🍩", "🍪", "🌰", "🥜", "🍯", "🥛", "🍼", "☕", "🍵", "🧃", "🥤", "🍶", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸", "🍹",
                "🧉", "🍾", "🧊", "🥄", "🍴", "🍽️", "🥣", "🥡", "🥢",
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
                "🪕", "🎻", "🎲", "♟️", "🎯", "🎳", "🎮", "🎰", "🧩",
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
                                            .cornerRadius(8)
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
    do {
        let previewer = try Previewer()

        return EditLabelView(label: previewer.label)
            .modelContainer(previewer.container)
            .environmentObject(Router())
            .environmentObject(SettingsManager())
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
