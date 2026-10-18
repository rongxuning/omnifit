import SwiftUI

enum AuthRoute: Hashable {
    case register
    case forgot
    case reset(String)
}

struct AuthFlow: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            LoginView(path: $path)
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .register:
                        RegisterView()
                    case .forgot:
                        ForgotPasswordView(path: $path)
                    case .reset(let email):
                        ResetPasswordView(email: email, path: $path)
                    }
                }
        }
    }
}

struct LoginView: View {
    @EnvironmentObject private var app: PhoneAppState
    @Binding var path: NavigationPath
    @State private var name = ""
    @State private var password = ""
    @State private var error = ""

    var body: some View {
        ZStack {
            CanvasBackground()
            VStack {
                Spacer()
                VStack(spacing: 0) {
                    OmniWordmark()
                    Text("徒步与跑步")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                        .padding(.top, 10)
                    field("账号", text: $name, secure: false)
                        .padding(.top, 26)
                    field("密码", text: $password, secure: true)
                        .padding(.top, 14)
                    Button(action: submit) {
                        Text("登录")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .frame(height: 44)
                            .background(Color.omniCobalt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)
                    VStack(spacing: 10) {
                        Button("注册") { path.append(AuthRoute.register) }
                        Button("忘记密码") { path.append(AuthRoute.forgot) }
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.omniCobalt)
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                    if !error.isEmpty {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.omniInk)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    } else if !app.banner.isEmpty {
                        Text(app.banner)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.omniCobalt)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 28)
                .frame(width: 276)
                .glass()
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    private func submit() {
        do {
            try app.login(name: name, password: password)
            error = ""
        } catch let failure as AuthFailure {
            error = failure.message
        } catch {
            self.error = "登录没有完成"
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .multilineTextAlignment(.center)
        .font(.system(size: 16, design: .rounded))
        .foregroundStyle(Color.omniInk)
        .frame(height: 48)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.omniIce.opacity(0.9), lineWidth: 1)
        )
    }
}

struct RegisterView: View {
    @EnvironmentObject private var app: PhoneAppState
    @State private var name = ""
    @State private var password = ""
    @State private var email = ""
    @State private var error = ""

    var body: some View {
        ZStack {
            CanvasBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AuthCard {
                        field("账号", text: $name)
                        field("密码", text: $password, secure: true)
                        Text("邮箱（必填，用于接收重置验证码）")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.omniMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 18)
                        field("邮箱", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                        primaryButton("注册", action: submit)
                        if !error.isEmpty {
                            Text(error)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.omniInk)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 12)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(Color.omniInk)
    }

    private func submit() {
        do {
            try app.register(name: name, password: password, email: email)
        } catch let failure as AuthFailure {
            error = failure.message
        } catch {
            self.error = "注册没有完成"
        }
    }
}

struct ForgotPasswordView: View {
    @EnvironmentObject private var app: PhoneAppState
    @Binding var path: NavigationPath
    @State private var email = ""
    @State private var code = ""
    @State private var prepared = false
    @State private var error = ""

    var body: some View {
        ZStack {
            CanvasBackground()
            ScrollView {
                AuthCard {
                    field("邮箱", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    primaryButton("获取验证码", action: requestCode)
                    if prepared {
                        Text("本地演示。验证码不会发到邮箱，也没有位数或有效期。请原样输入下面的演示验证码。")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.omniMuted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 16)
                        Text(LocalDemoCode.token)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.omniCobalt)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                        field("验证码", text: $code)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        primaryButton("验证", action: verify)
                    }
                    if !error.isEmpty {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.omniInk)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(Color.omniInk)
    }

    private func requestCode() {
        do {
            try app.prepareReset(email: email)
            prepared = true
            error = ""
        } catch let failure as AuthFailure {
            prepared = false
            error = failure.message
        } catch {
            self.error = "没有完成"
        }
    }

    private func verify() {
        do {
            try app.verifyReset(email: email, code: code)
            path.append(AuthRoute.reset(email.trimmingCharacters(in: .whitespacesAndNewlines)))
        } catch let failure as AuthFailure {
            error = failure.message
        } catch {
            self.error = "没有完成"
        }
    }
}

struct ResetPasswordView: View {
    @EnvironmentObject private var app: PhoneAppState
    @Binding var path: NavigationPath
    var email: String
    @State private var password = ""
    @State private var confirm = ""
    @State private var error = ""

    var body: some View {
        ZStack {
            CanvasBackground()
            ScrollView {
                AuthCard {
                    field("新密码", text: $password, secure: true)
                    field("确认密码", text: $confirm, secure: true)
                    primaryButton("重置密码", action: submit)
                    if !error.isEmpty {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.omniInk)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(Color.omniInk)
    }

    private func submit() {
        do {
            try app.resetPassword(email: email, password: password, confirm: confirm)
            path = NavigationPath()
        } catch let failure as AuthFailure {
            error = failure.message
        } catch {
            self.error = "没有完成"
        }
    }
}

private struct AuthCard<Content: View>: View {
    @ViewBuilder private var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .glass()
    }
}

@ViewBuilder
private func field(_ placeholder: String, text: Binding<String>, secure: Bool = false) -> some View {
    Group {
        if secure {
            SecureField(placeholder, text: text)
        } else {
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
    .multilineTextAlignment(.center)
    .font(.system(size: 16, design: .rounded))
    .foregroundStyle(Color.omniInk)
    .frame(maxWidth: .infinity)
    .frame(height: 48)
    .padding(.horizontal, 12)
    .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.omniIce.opacity(0.9), lineWidth: 1)
    )
    .padding(.top, 14)
}

private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.omniCobalt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
    .padding(.top, 20)
}
