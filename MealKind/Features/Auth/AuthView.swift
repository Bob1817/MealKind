import AuthenticationServices
import SwiftUI

struct AuthView: View {
    let language: AppLanguage
    let onAuthenticated: (AccountSession) -> Void
    var showsGuestContinue = false

    @State private var mode: AuthMode = .login
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var message: String?
    @FocusState private var focusedField: AuthField?

    private let authService = AccountAuthService()

    var body: some View {
        ZStack {
            AuthBackground()

            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 44)

                    VStack(spacing: 24) {
                        header
                        fields
                        primaryButton
                        divider
                        appleButton
                        footer
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 30)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .overlay(cardBorder)
                    .shadow(color: .black.opacity(0.44), radius: 34, x: 0, y: 22)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 430)

                    Spacer(minLength: 34)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(mode.title(language: language))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(mode.subtitle(language: language))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 14)
    }

    private var fields: some View {
        VStack(spacing: 12) {
            if mode == .register {
                AuthTextField(
                    title: language == .simplifiedChinese ? "昵称" : "Name",
                    text: $name,
                    systemImage: "person.fill",
                    contentType: .name,
                    submitLabel: .next
                )
                .focused($focusedField, equals: .name)
                .onSubmit { focusedField = .email }
            }

            AuthTextField(
                title: "Email",
                text: $email,
                systemImage: "envelope.fill",
                contentType: .emailAddress,
                keyboardType: .emailAddress,
                textInputAutocapitalization: .never,
                submitLabel: .next
            )
            .focused($focusedField, equals: .email)
            .onSubmit { focusedField = .password }

            AuthSecureField(
                title: language == .simplifiedChinese ? "密码" : "Password",
                text: $password,
                submitLabel: .go
            )
            .focused($focusedField, equals: .password)
            .onSubmit { Task { await submit() } }

            if let message {
                Text(message)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(messageIsError ? Color.red.opacity(0.90) : MKColor.mint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
        }
    }

    private var primaryButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text(mode.actionTitle(language: language))
                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.bold))
                }
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.48, green: 1.0, blue: 0.88), MKColor.green],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .shadow(color: MKColor.mint.opacity(0.32), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private var divider: some View {
        HStack(spacing: 14) {
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
            Text("OR")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.48))
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success:
                message = language == .simplifiedChinese
                    ? "Apple 登录需要开发者账号启用 Sign in with Apple 能力。"
                    : "Sign in with Apple needs the app capability enabled in the developer account."
            case .failure(let error):
                message = error.localizedDescription
            }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 50)
        .clipShape(Capsule())
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    mode = mode == .login ? .register : .login
                    message = nil
                    focusedField = mode == .register ? .name : .email
                }
            } label: {
                HStack(spacing: 4) {
                    Text(mode.switchPrompt(language: language))
                        .foregroundStyle(.white.opacity(0.60))
                    Text(mode.switchAction(language: language))
                        .foregroundStyle(MKColor.mint)
                }
                .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.44), .white.opacity(0.08), MKColor.mint.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var messageIsError: Bool {
        guard let message else { return false }
        return !message.contains("成功") && !message.localizedCaseInsensitiveContains("success")
    }

    @MainActor
    private func submit() async {
        guard isLoading == false else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            message = language == .simplifiedChinese ? "请输入有效邮箱。" : "Enter a valid email."
            return
        }
        guard password.count >= 8 else {
            message = language == .simplifiedChinese ? "密码至少需要 8 位。" : "Password needs at least 8 characters."
            return
        }

        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            let session: AccountSession
            if mode == .login {
                session = try await authService.login(email: trimmedEmail, password: password, language: language)
            } else {
                session = try await authService.register(
                    email: trimmedEmail,
                    password: password,
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    language: language
                )
            }
            message = language == .simplifiedChinese ? "登录成功。" : "Signed in."
            onAuthenticated(session)
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct AuthBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.038, blue: 0.042).ignoresSafeArea()

            RadialGradient(
                colors: [MKColor.mint.opacity(0.58), .clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 280
            )
            .blur(radius: 14)
            .ignoresSafeArea()

            LinearGradient(
                colors: [.white.opacity(0.08), .clear, .black.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

private struct AuthTextField: View {
    let title: String
    @Binding var text: String
    let systemImage: String
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var textInputAutocapitalization: TextInputAutocapitalization? = .sentences
    var submitLabel: SubmitLabel = .done

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MKColor.mint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.56))
                TextField(title, text: $text)
                    .textContentType(contentType)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(textInputAutocapitalization)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 58)
        .background(.white.opacity(0.075), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
    }
}

private struct AuthSecureField: View {
    let title: String
    @Binding var text: String
    var submitLabel: SubmitLabel = .done

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MKColor.mint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.56))
                SecureField(title, text: $text)
                    .textContentType(.password)
                    .submitLabel(submitLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 58)
        .background(.white.opacity(0.075), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
    }
}

private enum AuthMode {
    case login
    case register

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.login, .simplifiedChinese):
            return "欢迎回来"
        case (.register, .simplifiedChinese):
            return "创建账号"
        case (.login, _):
            return "Welcome back"
        case (.register, _):
            return "Create account"
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch (self, language) {
        case (.login, .simplifiedChinese):
            return "登录并同步你的记录"
        case (.register, .simplifiedChinese):
            return "保存餐食、周期和身体记录"
        case (.login, _):
            return "Sign in and sync your records"
        case (.register, _):
            return "Save meals, cycles, and body logs"
        }
    }

    func actionTitle(language: AppLanguage) -> String {
        switch (self, language) {
        case (.login, .simplifiedChinese):
            return "登录"
        case (.register, .simplifiedChinese):
            return "注册"
        case (.login, _):
            return "Sign in"
        case (.register, _):
            return "Sign up"
        }
    }

    func switchPrompt(language: AppLanguage) -> String {
        switch (self, language) {
        case (.login, .simplifiedChinese):
            return "还没有账号？"
        case (.register, .simplifiedChinese):
            return "已有账号？"
        case (.login, _):
            return "Do not have an account?"
        case (.register, _):
            return "Already have an account?"
        }
    }

    func switchAction(language: AppLanguage) -> String {
        switch (self, language) {
        case (.login, .simplifiedChinese):
            return "注册"
        case (.register, .simplifiedChinese):
            return "登录"
        case (.login, _):
            return "Sign up"
        case (.register, _):
            return "Sign in"
        }
    }
}

private enum AuthField {
    case name
    case email
    case password
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview {
    AuthView(language: .simplifiedChinese) { _ in }
}
