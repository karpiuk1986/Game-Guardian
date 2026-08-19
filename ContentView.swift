import SwiftUI
import UniformTypeIdentifiers

struct ModItem: Identifiable {
    let id = UUID()
    var key: String
    var value: String
    var originalType: String
}

struct NetworkLog: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let endpoint: String
    let status: String
    let responseBody: String
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var isImporting = false
    @State private var fileURL: URL?
    @State private var fileName: String = "Файл не обрано"
    @State private var modItems: [ModItem] = []
    @State private var searchQuery: String = ""
    
    @State private var targetURL: String = "https://api.game-server.com/v1/user/reward"
    @State private var httpMethod: String = "POST"
    @State private var customHeaders: String = "Authorization: Bearer token_here\nContent-Type: application/json"
    @State private var jsonPayload: String = "{\n  \"action\": \"add_coins\",\n  \"amount\": 999999,\n  \"receipt_bypass\": true\n}"
    @State private var logs: [NetworkLog] = []
    @State private var isSendingRequest = false
    
    @State private var showSaveAlert = false
    @State private var alertMessage = ""
    
    var filteredItems: [ModItem] {
        if searchQuery.isEmpty {
            return modItems
        } else {
            return modItems.filter { $0.key.localizedCaseInsensitiveContains(searchQuery) || $0.value.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                VStack(spacing: 0) {
                    fileHeaderView
                    
                    if !modItems.isEmpty {
                        searchBarView
                        
                        List {
                            Section(header: Text("Параметри гри (Змініть та збережіть)")) {
                                ForEach(filteredItems.indices, id: \.self) { index in
                                    let realIndex = modItems.firstIndex(where: { $0.id == filteredItems[index].id }) ?? index
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(modItems[realIndex].key)
                                                .font(.body)
                                                .fontWeight(.medium)
                                            Text("Тип: \(modItems[realIndex].originalType)")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        TextField("Значення", text: $modItems[realIndex].value)
                                            .multilineTextAlignment(.trailing)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.blue)
                                            .fontWeight(.bold)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(width: 140)
                                    }
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                        
                        Button(action: saveChanges) {
                            HStack {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text("Зберегти файл")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                        }
                    } else {
                        emptyFilePlaceholder
                    }
                }
                .navigationTitle("Local File Modder")
                .fileImporter(
                    isPresented: $isImporting,
                    allowedContentTypes: [.data, .json, .propertyList, .plainText],
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImport(result: result)
                }
            }
            .tabItem {
                Label("Офлайн Файли", systemName: "doc.badge.gearshape")
            }
            .tag(0)

            NavigationView {
                Form {
                    Section(header: Text("Параметри запиту до сервера гри")) {
                        TextField("URL сервера або API ендпоінт", text: $targetURL)
                            .autocapitalizing(.none)
                            .disableAutocorrection(true)
                            .font(.system(.subheadline, design: .monospaced))
                        
                        Picker("HTTP Метод", selection: $httpMethod) {
                            Text("POST").tag("POST")
                            Text("PUT").tag("PUT")
                            Text("GET").tag("GET")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section(header: Text("Заголовки (Headers / Auth Tokens)")) {
                        TextEditor(text: $customHeaders)
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 60)
                    }

                    Section(header: Text("JSON Payload (Пейлоад нарахування)")) {
                        TextEditor(text: $jsonPayload)
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 100)
                    }

                    Section {
                        Button(action: executeOnlineRequest) {
                            HStack {
                                Spacer()
                                if isSendingRequest {
                                    ProgressView()
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("Відправити пейлоад на сервер")
                                        .fontWeight(.bold)
                                }
                                Spacer()
                            }
                        }
                        .foregroundColor(.white)
                        .listRowBackground(Color.blue)
                        .disabled(isSendingRequest)
                    }

                    Section(header: Text("Журнал відповідей сервера")) {
                        if logs.isEmpty {
                            Text("Запитів ще не відправлялось")
                                .foregroundColor(.gray)
                                .font(.caption)
                        } else {
                            ForEach(logs) { log in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(log.status)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(log.status.contains("200") || log.status.contains("OK") ? .green : .red)
                                        Spacer()
                                        Text(log.timestamp, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Text(log.endpoint)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .foregroundColor(.secondary)
                                    Text(log.responseBody)
                                        .font(.system(.caption2, design: .monospaced))
                                        .padding(6)
                                        .background(Color(.tertiarySystemGroupedBackground))
                                        .cornerRadius(6)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .navigationTitle("Online API Tester")
            }
            .tabItem {
                Label("Онлайн Спроби", systemName: "network")
            }
            .tag(1)
        }
        .alert(isPresented: $showSaveAlert) {
            Alert(title: Text("Результат"), message: Text(alertMessage), dismissButton: .default(Text("ОК")))
        }
    }

    private var fileHeaderView: View {
        HStack {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.headline)
                    .lineLimit(1)
                Text(fileURL == nil ? "Оберіть файл збереження гри" : "Файл завантажено")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { isImporting = true }) {
                Text("Відкрити")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding()
    }

    private var searchBarView: View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Шукати (coins, gems, level)...", text: $searchQuery)
                .autocapitalizing(.none)
            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var emptyFilePlaceholder: View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text("Локальний та Онлайн Інструмент")
                .font(.title3)
                .fontWeight(.bold)
            Text("• Для офлайн ігор: відкрийте файл .plist або .json\n• Для онлайн ігор: перейдіть у вкладку 'Онлайн Спроби' для перевірки відповіді API сервера.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer()
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        do {
            guard let selectedFile = try result.get().first else { return }
            if selectedFile.startAccessingSecurityScopedResource() {
                defer { selectedFile.stopAccessingSecurityScopedResource() }
                self.fileURL = selectedFile
                self.fileName = selectedFile.lastPathComponent
                parseFile(url: selectedFile)
            }
        } catch {
            alertMessage = "Помилка відкриття: \(error.localizedDescription)"
            showSaveAlert = true
        }
    }

    private func parseFile(url: URL) {
        modItems.removeAll()
        do {
            let data = try Data(contentsOf: url)
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                for (key, value) in jsonObject {
                    modItems.append(ModItem(key: key, value: "\(value)", originalType: "JSON"))
                }
                return
            }
            if let plistObject = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                for (key, value) in plistObject {
                    modItems.append(ModItem(key: key, value: "\(value)", originalType: "PLIST"))
                }
                return
            }
        } catch {
            alertMessage = "Помилка аналізу файлу."
            showSaveAlert = true
        }
    }

    private func saveChanges() {
        guard let url = fileURL else { return }
        var dictToSave: [String: Any] = [:]
        for item in modItems {
            if let intVal = Int(item.value) { dictToSave[item.key] = intVal }
            else if let doubleVal = Double(item.value) { dictToSave[item.key] = doubleVal }
            else if item.value.lowercased() == "true" { dictToSave[item.key] = true }
            else if item.value.lowercased() == "false" { dictToSave[item.key] = false }
            else { dictToSave[item.key] = item.value }
        }
        
        do {
            if url.pathExtension.lowercased() == "plist" {
                let plistData = try PropertyListSerialization.data(fromPropertyList: dictToSave, format: .xml, options: 0)
                try plistData.write(to: url)
            } else {
                let jsonData = try JSONSerialization.data(withJSONObject: dictToSave, options: .prettyPrinted)
                try jsonData.write(to: url)
            }
            alertMessage = "Зміни збережено в файл!"
            showSaveAlert = true
        } catch {
            alertMessage = "Помилка збереження: \(error.localizedDescription)"
            showSaveAlert = true
        }
    }

    private func executeOnlineRequest() {
        guard let url = URL(string: targetURL) else {
            alertMessage = "Некоректний URL"
            showSaveAlert = true
            return
        }
        
        isSendingRequest = true
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        
        let headerLines = customHeaders.components(separatedBy: .newlines)
        for line in headerLines {
            let parts = line.components(separatedBy: ":")
            if parts.count == 2 {
                let headerKey = parts[0].trimmingCharacters(in: .whitespaces)
                let headerVal = parts[1].trimmingCharacters(in: .whitespaces)
                request.setValue(headerVal, forHTTPHeaderField: headerKey)
            }
        }
        
        if httpMethod != "GET" {
            request.httpBody = jsonPayload.data(using: .utf8)
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isSendingRequest = false
                if let error = error {
                    logs.insert(NetworkLog(endpoint: targetURL, status: "ERROR", responseBody: error.localizedDescription), at: 0)
                    return
                }
                
                let httpResponse = response as? HTTPURLResponse
                let statusCode = httpResponse?.statusCode ?? 0
                let statusString = "HTTP \(statusCode)"
                
                var bodyString = "Немає даних у відповіді"
                if let data = data, let str = String(data: data, encoding: .utf8) {
                    bodyString = str
                }
                
                logs.insert(NetworkLog(endpoint: targetURL, status: statusString, responseBody: bodyString), at: 0)
                
                if statusCode == 200 || statusCode == 201 {
                    alertMessage = "Сервер прийняв запит! Відповідь отримано."
                    showSaveAlert = true
                }
            }
        }.resume()
    }
}
