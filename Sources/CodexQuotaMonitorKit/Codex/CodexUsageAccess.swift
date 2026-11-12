// 목적: 서버가 판별한 포함 사용량·지출 제한의 독립 보관
// 이용처: Codex 계정 상태와 초기화 오인 방지
// 사용방법: 한도 응답 파싱 후 이전 관측과 병합
// 실행 예시: access.merging(previous: previousAccess)
import Foundation

/// 사용률과 독립적인 서버 사용 허용 근거
public struct CodexUsageAccess: Codable, Equatable, Sendable {
    public var ordinaryUsageAllowed: Bool?
    public var spendControlReached: Bool?
    public var reachedType: String?

    /// 명시적 서버 차단 여부
    public var isBlocked: Bool {
        ordinaryUsageAllowed == false || spendControlReached == true || reachedType != nil
    }

    /// 민감한 서버 원문 없는 차단 안내
    public var message: String? {
        guard isBlocked else { return nil }
        if spendControlReached == true { return "Codex - 지출 한도에 도달했습니다." }
        switch reachedType {
        case "workspace_owner_credits_depleted", "workspace_member_credits_depleted":
            return "Codex - 워크스페이스 크레딧이 소진되었습니다."
        case "workspace_owner_usage_limit_reached", "workspace_member_usage_limit_reached":
            return "Codex - 워크스페이스 사용 한도에 도달했습니다."
        default: return "Codex - 서버에서 포함 사용량 이용을 제한했습니다."
        }
    }

    /// 누락·null 응답을 차단 해제 근거로 사용하지 않는 병합
    public func merging(previous: Self?) -> Self {
        Self(ordinaryUsageAllowed: ordinaryUsageAllowed ?? previous?.ordinaryUsageAllowed,
             spendControlReached: spendControlReached ?? previous?.spendControlReached,
             reachedType: reachedType ?? (ordinaryUsageAllowed == true ? nil : previous?.reachedType))
    }

    /// 현재 버킷의 알려진 차단 코드만 허용하는 응답 투영
    static func parse(result: [String: CodexJSONValue], limits: [String: CodexJSONValue]) -> Self {
        let known = ["rate_limit_reached", "workspace_owner_credits_depleted", "workspace_member_credits_depleted",
                     "workspace_owner_usage_limit_reached", "workspace_member_usage_limit_reached"]
        let reason = limits["rateLimitReachedType"]?.stringValue
        return Self(ordinaryUsageAllowed: result["ordinaryUsageAllowed"]?.boolValue,
                    spendControlReached: limits["spendControlReached"]?.boolValue,
                    reachedType: reason.flatMap { known.contains($0) ? $0 : nil })
    }
}
