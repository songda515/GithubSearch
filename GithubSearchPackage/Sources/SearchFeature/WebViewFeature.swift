import ComposableArchitecture
import Foundation

/// 선택한 저장소를 `title`/`url` 로 표시하는 웹뷰. 표시 전용이라 별도 액션/부수효과가 없다.
/// 상위 `SearchFeature` 가 destination 으로 push 한다. (docs/specs/webview/spec.md)
@Reducer
public struct WebViewFeature {
    @ObservableState
    public struct State: Equatable {
        /// navigation title (저장소 이름).
        public var title: String
        /// 표시할 웹 콘텐츠 주소.
        public var url: URL

        public init(title: String, url: URL) {
            self.title = title
            self.url = url
        }
    }

    public enum Action: Equatable {}

    public init() {}

    public var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}
