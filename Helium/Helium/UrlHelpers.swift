//
//  UrlHelpers.swift
//  Helium
//
//  Created by Viktor Oreshkin on 9.5.17.
//  Copyright © 2017 Jaden Geller. All rights reserved.
//

import Foundation

struct UrlHelpers {
	/// Prepends `http://` if scheme isn't `https?://`
	static func ensureScheme(_ urlString: String) -> String {
		if !(urlString.lowercased().hasPrefix("http://") || urlString.lowercased().hasPrefix("https://")) {
			return "http://" + urlString
		} else {
			return urlString
		}
	}
}

// MARK: - Magic Handlers
extension UrlHelpers {
	class Magic {
		fileprivate var modified: URLComponents
		fileprivate var converted: Bool = false
		public var newUrl: URL? {
			get {
				return self.converted ? self.modified.url : nil
			}
		}

		fileprivate let url: URL
		fileprivate let urlString: String

		init(_ url: URL) {
			self.url = url
			self.urlString = url.absoluteString

			self.modified = URLComponents()
			self.modified.scheme = url.scheme

			// Paranoind check
			if url.host != nil {
				self.converted = self.YouTube() ||
					self.Twitch() ||
					self.Vimeo() ||
					self.Youku() ||
					self.DailyMotion()
			}
		}
	}
}

// MARK: Generic Handler Factory - just replaces prefix
extension UrlHelpers.Magic {
	fileprivate static func GenericFactory(prefix: String, replacement: String) -> ((UrlHelpers.Magic) -> Bool) {
		return { (instance: UrlHelpers.Magic) in
			if instance.urlString.hasPrefix(prefix) {
				let urlStringModified = instance.urlString.replacePrefix(prefix, replacement: replacement)
				if let newComponents = URLComponents(string: urlStringModified) {
					instance.modified = newComponents
					return true
				}
			}
			return false
		}
	}
}

// MARK: Youku Handler
extension UrlHelpers.Magic {
	private static let YoukuClosure = UrlHelpers.Magic.GenericFactory(prefix: "http://v.youku.com/v_show/id_", replacement: "http://player.youku.com/embed/")

	fileprivate func Youku() -> Bool {
		return UrlHelpers.Magic.YoukuClosure(self)
	}
}

// MARK: DailyMotion Handler
extension UrlHelpers.Magic {
	private static let Short = UrlHelpers.Magic.GenericFactory(prefix: "http://www.dailymotion.com/video/", replacement: "http://www.dailymotion.com/embed/video/")

	private static let Full = UrlHelpers.Magic.GenericFactory(prefix: "http://dai.ly/video/", replacement: "http://www.dailymotion.com/embed/video/")

	fileprivate func DailyMotion() -> Bool {
		return UrlHelpers.Magic.Full(self) || UrlHelpers.Magic.Short(self)
	}
}

// MARK: Twitch.tv Handler
extension UrlHelpers.Magic {
	fileprivate func Twitch() -> Bool {
		let TwitchRegExp = try! NSRegularExpression(pattern: "https?://(?:www\\.)?twitch\\.tv/([\\w\\d\\_]+)(?:/(\\d+))?")

		if let match = TwitchRegExp.firstMatch(in: urlString, range: urlString.nsrange),
			let channel = urlString.substring(with:match.rangeAt(1))
		{
			switch(channel) {
			case "directory", "products", "p", "user":
				break
			case "videos":
				if let idString = urlString.substring(with:match.rangeAt(2)) {
					modified.host = "player.twitch.tv"
					modified.query = "html5&video=v" + idString
					return true
				}
			default:
				modified.host = "player.twitch.tv"
				modified.query = "html5&channel=" + channel
				return true
			}
		}

		return false
	}
}

// MARK: Vimeo Handler
extension UrlHelpers.Magic {
	fileprivate func Vimeo() -> Bool {
		let urlStringModified = self.urlString.replacingOccurrences(of: "(?:https?://)?(?:www\\.)?vimeo\\.com/(\\d+)", with: "https://player.vimeo.com/video/$1", options: .regularExpression)
		if urlStringModified != self.urlString, let newComponents = URLComponents(string: urlStringModified) {
			self.modified = newComponents

			return true
		}

		return false
	}
}

// MARK: YouTube Handler
extension UrlHelpers.Magic {
	fileprivate func YouTube() -> Bool {
		// (video id) (hours)?(minutes)?(seconds)
		let YTRegExp = try! NSRegularExpression(pattern: "(?:https?://)?(?:www\\.)?(?:youtube\\.com/watch\\?v=|youtu.be/)([\\w\\_\\-]+)(?:[&?]t=(?:(\\d+)h)?(?:(\\d+)m)?(?:(\\d+)s?))?")

		if let match = YTRegExp.firstMatch(in: self.urlString, range: self.urlString.nsrange) {
			self.modified.host = "youtube.com"
			self.modified.path = "/embed/" + self.urlString.substring(with: match.rangeAt(1))!

			var start = 0
			var multiplier = 60 * 60
			for idx in 2...4 {
				if let tStr = self.urlString.substring(with: match.rangeAt(idx)), let tInt = Int(tStr) {
					start += tInt * multiplier
				}
				multiplier /= 60
			}
			if start != 0 {
				self.modified.query = "start=" + String(start)
			}

			return true
		}

		return false
	}
}
