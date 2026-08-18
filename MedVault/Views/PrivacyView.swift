import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.teal)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Конфиденциальность")
                    .font(.largeTitle.bold())

                Text("Ваши документы хранятся на устройстве. Приложение не отправляет медицинские документы на сервер.")
                    .font(.title3)

                PrivacyCard(
                    symbol: "internaldrive.fill",
                    title: "Локальное хранение",
                    message: "Оригиналы файлов и сохранённые записи размещаются в изолированном хранилище приложения на вашем устройстве."
                )
                PrivacyCard(
                    symbol: "text.viewfinder",
                    title: "Локальное распознавание",
                    message: "Для изображений используется Apple Vision, а текст PDF извлекается с помощью PDFKit. MedVault не использует сетевой сервис для обработки документа."
                )
                PrivacyCard(
                    symbol: "nosign",
                    title: "Без учётных записей, рекламы и аналитики",
                    message: "В MVP нет регистрации, рекламы, аналитики или фоновой отправки медицинских данных."
                )

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Важно")
                        .font(.headline)
                    Text("MedVault помогает хранить и отображать информацию из документов. Он не является медицинским диагностическим инструментом и не предоставляет медицинских рекомендаций.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyCard: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.teal)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
