//
//  DSMAccount.swift
//  dsmaccess
//
//  Comptes et groupes locaux exposés par SYNO.Core.User et SYNO.Core.Group.
//

import Foundation

struct DSMUser: Decodable, Identifiable, Hashable, Sendable {
    let name: String
    let description: String?
    let email: String?
    let uid: Int?
    let expiration: String?
    let groups: [String]
    let isAdministrator: Bool

    var id: String { name }

    var isDisabled: Bool {
        guard let expiration else { return false }
        return ["now", "expired", "disabled", "true"].contains(expiration.lowercased())
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description = "desc"
        case alternateDescription = "description"
        case email
        case uid
        case expiration = "expired"
        case groups
        case admin
        case isAdmin = "is_admin"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = values.flexString(.name) ?? ""
        description = values.flexString(.description) ?? values.flexString(.alternateDescription)
        email = values.flexString(.email)
        uid = values.flexInt(.uid)
        expiration = values.flexString(.expiration)
        groups = (try? values.decode([String].self, forKey: .groups)) ?? []
        isAdministrator = values.flexBool(.admin) ?? values.flexBool(.isAdmin) ?? groups.contains("administrators")
    }
}

struct DSMGroup: Decodable, Identifiable, Hashable, Sendable {
    let name: String
    let description: String?
    let gid: Int?
    let members: [String]

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case description = "desc"
        case alternateDescription = "description"
        case gid
        case users
        case members
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = values.flexString(.name) ?? ""
        description = values.flexString(.description) ?? values.flexString(.alternateDescription)
        gid = values.flexInt(.gid)
        members = (try? values.decode([String].self, forKey: .users))
            ?? (try? values.decode([String].self, forKey: .members))
            ?? []
    }
}

struct DSMUserList: Decodable, Sendable {
    let users: [DSMUser]

    enum CodingKeys: String, CodingKey { case users }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        users = (try? values.decode([DSMUser].self, forKey: .users)) ?? []
    }
}

struct DSMGroupList: Decodable, Sendable {
    let groups: [DSMGroup]

    enum CodingKeys: String, CodingKey { case groups }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        groups = (try? values.decode([DSMGroup].self, forKey: .groups)) ?? []
    }
}

struct DSMUserDraft: Sendable {
    let name: String
    let password: String
    let description: String
    let email: String
    let groups: [String]
}

struct DSMGroupDraft: Sendable {
    let name: String
    let description: String
}
