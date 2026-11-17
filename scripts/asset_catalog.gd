class_name AssetCatalog
extends RefCounted

# Curated bundled manifest. Saved fighters resolve IDs here, never file paths.
const PACKS := {
	"modular-characters": {
		"name": "Modular Characters",
		"creator": "Kenney / Kenney Vleugels",
		"source": "https://kenney.nl/assets/modular-characters",
		"source_kind": "bundled_third_party",
		"acquisition": "Official free individual download; not authenticated through purchased bundle",
		"license": "CC0-1.0",
		"license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
		"license_file": "res://assets/third_party/kenney/modular-characters/LICENSE.txt",
		"attribution": "Optional: Kenney (kenney.nl)",
		"redistribution": "Commercial use, modification and redistribution allowed under CC0",
		"archive_sha256": "ff08976d4b93c10cca1e2d67a99588fa82e63737676be543d6f5929606c13b93",
		"reviewed_on": "2026-10-05"
	},
	"background-elements": {
		"name": "Background Elements",
		"creator": "Kenney / Kenney Vleugels",
		"source": "https://kenney.nl/assets/background-elements",
		"source_kind": "bundled_third_party",
		"acquisition": "Official free individual download; not authenticated through purchased bundle",
		"license": "CC0-1.0",
		"license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
		"license_file": "res://assets/third_party/kenney/background-elements/LICENSE.txt",
		"attribution": "Optional: Kenney (kenney.nl)",
		"redistribution": "Commercial use, modification and redistribution allowed under CC0",
		"archive_sha256": "31ffecec57bd51263f68e96e288ad06ac28eb1dfb41edb06b006a1b42cc10e41",
		"reviewed_on": "2026-10-05"
	},
	"impact-sounds": {
		"name": "Impact Sounds",
		"creator": "Kenney / Kenney Vleugels",
		"source": "https://kenney.nl/assets/impact-sounds",
		"source_kind": "bundled_third_party",
		"acquisition": "Official free individual download; not authenticated through purchased bundle",
		"license": "CC0-1.0",
		"license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
		"license_file": "res://assets/third_party/kenney/impact-sounds/LICENSE.txt",
		"attribution": "Optional: Kenney (kenney.nl)",
		"redistribution": "Commercial use, modification and redistribution allowed under CC0",
		"archive_sha256": "029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8",
		"reviewed_on": "2026-10-05"
	}
}

const ITEMS := {
	"kenney_hair_short": {
		"display_name": "Short sweep",
		"category": "Fighter Parts",
		"pack": "modular-characters",
		"tags": [
			"hair",
			"short",
			"fighter"
		],
		"original_file": "PNG/Hair/Black/blackMan1.png",
		"modifications": "None; renamed only. Display scaling is applied at runtime.",
		"sha256": "8f9b4c388a8d07e3c57b34ce9d054b3425bf114c90681179e706a0b6534bc707",
		"technical_notes": "158x119 RGBA PNG; static, transparent artwork",
		"resource": preload("res://assets/third_party/kenney/modular-characters/hair_short.png"),
		"head_rect": Rect2(-20,-20,40,30)
	},
	"kenney_hair_long": {
		"display_name": "Long sweep",
		"category": "Fighter Parts",
		"pack": "modular-characters",
		"tags": [
			"hair",
			"long",
			"fighter"
		],
		"original_file": "PNG/Hair/Brown 1/brown1Woman1.png",
		"modifications": "None; renamed only. Display scaling is applied at runtime.",
		"sha256": "0104b90ead251be1cf7751afa7050023aff83f86dda348fde82bbebed8bff9b2",
		"technical_notes": "158x285 RGBA PNG; static, transparent artwork",
		"resource": preload("res://assets/third_party/kenney/modular-characters/hair_long.png"),
		"head_rect": Rect2(-20,-20,40,72)
	},
	"kenney_hills": {
		"display_name": "Rolling hills",
		"category": "Backgrounds",
		"pack": "background-elements",
		"tags": [
			"hills",
			"arena",
			"scenery"
		],
		"original_file": "PNG/Flat/hills1.png",
		"modifications": "None; renamed only. Display scaling is applied at runtime.",
		"sha256": "1264021ed5a69b214d22dfa6562a6bed54ee0f9c374bfafa5f9165cabdf63800",
		"technical_notes": "1001x128 RGBA PNG; static, transparent artwork",
		"resource": preload("res://assets/third_party/kenney/background-elements/hills.png")
	},
	"kenney_tree": {
		"display_name": "Autumn tree",
		"category": "Stage Objects",
		"pack": "background-elements",
		"tags": [
			"tree",
			"arena",
			"decoration"
		],
		"original_file": "PNG/tree01.png",
		"modifications": "None; renamed only. Display scaling is applied at runtime.",
		"sha256": "cfc4b3d48000ea11839c5b5dd99ff3cdc138258888d1e2f9aaf3ef06d6697781",
		"technical_notes": "128x230 RGBA PNG; static, transparent artwork",
		"resource": preload("res://assets/third_party/kenney/background-elements/tree.png")
	},
	"kenney_castle": {
		"display_name": "Grey castle",
		"category": "Stage Objects",
		"pack": "background-elements",
		"tags": [
			"castle",
			"arena",
			"decoration"
		],
		"original_file": "PNG/castle_grey.png",
		"modifications": "None; renamed only. Display scaling is applied at runtime.",
		"sha256": "2239d78b87c5bd0b524339677ab646b6fce3a5e59200f49e3cde7a1790018cbc",
		"technical_notes": "204x182 RGBA PNG; static, transparent artwork",
		"resource": preload("res://assets/third_party/kenney/background-elements/castle.png")
	},
	"kenney_metal_hit": {
		"display_name": "Metal impact",
		"category": "Sounds",
		"pack": "impact-sounds",
		"tags": [
			"impact",
			"metal",
			"weapon"
		],
		"original_file": "Audio/impactMetal_medium_000.ogg",
		"modifications": "None; renamed only. Display scaling is applied at runtime.",
		"sha256": "a96f879fec0864a8938e0c745b6996a6c5679c16a234ce31a01cc995e8401003",
		"technical_notes": "Original Ogg Vorbis; weapon playback at -8 dB, preview at -12 dB",
		"resource": preload("res://assets/third_party/kenney/impact-sounds/metal_hit.ogg")
	},
	"kenney_wood_hit": {
		"display_name": "Wood impact",
		"category": "Sounds",
		"pack": "impact-sounds",
		"tags": [
			"impact",
			"wood",
			"weapon"
		],
		"original_file": "Audio/impactWood_medium_000.ogg",
		"modifications": "None; renamed only. Display scaling is applied at runtime.",
		"sha256": "1723a9fd25103ed41af06054814e84e65f4a772bac86ab2dc927da93d9592ff5",
		"technical_notes": "Original Ogg Vorbis; weapon playback at -8 dB, preview at -12 dB",
		"resource": preload("res://assets/third_party/kenney/impact-sounds/wood_hit.ogg")
	},
}


static func ids_for(category: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in ITEMS:
		if ITEMS[id]["category"] == category:
			ids.append(id)
	return ids


static func valid_choice(id: Variant, category: String) -> bool:
	return id is String and (id.is_empty() or (ITEMS.has(id) and ITEMS[id]["category"] == category))
