# New Field Test Images — Source Manifest

27 images across 23 confirmed classes, ready for `tools/evaluate_model.py`,
plus several unconfirmed/rejected candidates held separately.

| Filename | Class | Source | Credit |
|---|---|---|---|
| Banana___Sigatoka_yellow_01.jpg | Banana___Sigatoka | Common Pests and Diseases of Banana, PlantwisePlus/CABI 2013 | © D.R. Jones, INIBAP |
| Banana___Sigatoka_black_01.jpg | Banana___Sigatoka | Common Pests and Diseases of Banana, PlantwisePlus/CABI 2013 | © D.R. Jones, INIBAP |
| Cassava___Bacterial_Blight_01.jpg | Cassava___Bacterial_Blight | Common Pests and Diseases of Cassava, PlantwisePlus/CABI 2013 | © Graham Jackson |
| Cassava___Brown_Streak_Disease_01.jpg | Cassava___Brown_Streak_Disease | Common Pests and Diseases of Cassava, PlantwisePlus/CABI 2013 | Plantwise |
| Cassava___Green_Mite_01.jpg | Cassava___Green_Mite | Common Pests and Diseases of Cassava, PlantwisePlus/CABI 2013 | Plantwise |
| Cassava___Mosaic_01.jpg | Cassava___Mosaic | Common Pests and Diseases of Cassava, PlantwisePlus/CABI 2013 | Plantwise |
| Groundnut_leaf.jpg | Groundnut___Leaf_Raw | User-provided | — |
| Maize___Streak_Virus_01.jpg | Maize___Streak_Virus | Common Pests and Diseases of Maize, PlantwisePlus/CABI 2013 | Plantwise |
| Rice___Bacterial_Blight_02.jpg | Rice___Bacterial_Blight | IRRI Rice Knowledge Bank, Diseases index page | IRRI, CC |
| Rice___Bacterial_Blight_03.jpg | Rice___Bacterial_Blight | IRRI Rice Knowledge Bank, Diseases index page (low-res thumbnail crop — flagged) | IRRI, CC |
| Rice___Brown_Spot_01.jpg | Rice___Brown_Spot | Common Pests and Diseases of Rice, PlantwisePlus/CABI 2013 | © D. Groth, Loustate, Bugwood.org |
| Oryza_sativa_in_Kadavoor.jpg | Rice___Healthy | Wikimedia Commons | Check file license page |
| Rice_field_at_Pavannur__12_.jpg | Rice___Healthy | Wikimedia Commons | Check file license page |
| Rice___Leaf_Blast_01.jpg | Rice___Leaf_Blast | Common Pests and Diseases of Rice, PlantwisePlus/CABI 2013 | © O.P. Sharma, NCIPM, Bugwood.org |
| Rice___Leaf_Scald_01.jpg | Rice___Leaf_Scald | Common Pests and Diseases of Rice, PlantwisePlus/CABI 2013 | © D. Groth, Loustate, Bugwood.org |
| Rice___Sheath_Blight_01.jpg | Rice___Sheath_Blight | IRRI Rice Knowledge Bank, Sheath Blight fact sheet | IRRI, CC — content experts Adam Sparks, NP Castilla, CM Vera Cruz |
| Rice___Sheath_Blight_02.jpg | Rice___Sheath_Blight | IRRI Rice Knowledge Bank, Sheath Blight fact sheet | IRRI, CC |
| Tomato___Leaf_Curl_01.jpg | Tomato___Leaf_Curl | Common Diseases on Tomato in Ghana, PlantwisePlus 2018 | © Ian D. Bedford, CABI |

| Cordana_leaf_spot_by_Cordana_musae.jpg | Banana___Cordana | User-provided | Filename-confirmed, exact pathogen match |
| Oulema_melanopus__Basel.jpg | Maize___Leaf_Beetle | User-provided | Filename-confirmed (Oulema melanopus = cereal leaf beetle) |
| Grasshoppers_on_corn.jpg | Maize___Grasshopper | User-provided | Filename-confirmed |
| Spodoptera_frugiperda_in_stalk_of_Zea_mays.jpg | Maize___Fall_Armyworm | User-provided | Filename-confirmed (S. frugiperda = fall armyworm) |
| Mango___Anthracnose_01.jpg | Mango___Anthracnose | Common Pests and Diseases on Mango in Ghana, PlantwisePlus 2018 | © Scot Nelson, Flikr |
| Mango___Powdery_Mildew_01.jpg | Mango___Powdery_Mildew | Common Pests and Diseases on Mango in Ghana, PlantwisePlus 2018 | © Mary Musyoka; AA Seif, ICIPE; Scot Nelson |
| Septoria_lycopersici_malagutii_leaf_spot_on_tomato_leaf.jpg | Tomato___Septoria_Leaf_Spot | User-provided (Bugwood ID 5586158) | Filename-confirmed |

| Mango_tree_leaf.jpg | Mango___Healthy | User-provided | — |
| leaf-cutting-weevil-mango-1703078332.jpg | Mango___Cutting_Weevil | User-provided | Filename-confirmed |

## Held for review — NOT in test_set, do not evaluate until decided

| Filename | Candidate class | Source | Note |
|---|---|---|---|
| Tomato___Leaf_Blight_UNCONFIRMED_01.jpg | Tomato___Leaf_Blight (unconfirmed) | Common Pests and Diseases of Tomato, PlantwisePlus/CABI 2013 — "Late blight" (Phytophthora infestans) | Uncertain match to training label's intent |
| Tomato___Leaf_Blight_UNCONFIRMED_02_earlyblight.jpg | Tomato___Leaf_Blight (unconfirmed) | Common Diseases on Tomato in Ghana, PlantwisePlus 2018 — "Early blight" (Alternaria solani) | Stronger candidate (Ghana-specific), still unconfirmed |
| Maize___UNKNOWN_disease_class_01.jpg | Maize (class unknown) | User-provided, generic filename, no disease name given | Lesion shape suggests a blight/leaf-spot type disease but cannot be confidently assigned to any specific maize class |
| Mango___Bacterial_Canker_UNCONFIRMED_01.jpg | Mango___Bacterial_Canker (unconfirmed) | Common Pests and Diseases on Mango in Ghana, PlantwisePlus 2018 — "Bacterial black spot" (Xanthomonas axonopodis pv. mangiferaeindicae) | Likely same disease as Bacterial_Canker under a different common name — same pathogen — but naming not 100% certain to match training label intent |

| Maize___UNKNOWN_field_senescence_or_disease.jpg | Maize (unclear) | User-provided, generic filename "images.jpg" | Looks like natural late-season senescence (tassel/leaf browning at maturity) rather than a specific disease symptom — no confident class match |

## Rejected — wrong species, not usable at all

Three images from this batch were rejected outright rather than held for
review, because they show the wrong organism entirely, not just an
uncertain match:

- **"Corymbia-torelliana"** (submitted as a possible Mango image) — this is
  a spotted gum/bloodwood, an Australian eucalypt. Not *Mangifera indica*.
- **"Obolodiplosis robiniae ... Locust gall midge"** (submitted as a
  possible `Mango___Gall_Midge` image) — this insect and its galls affect
  *Robinia* (black locust), a different species from the mango gall midge
  (*Procontarinia mangiferae*/*matteiana*). Same insect family, wrong
  species, wrong host plant.
- **Generic "Cecidomyiidae"** (also submitted for `Gall_Midge`) — identified
  only to family level (thousands of species across many plants); the leaf
  shown doesn't match mango foliage either.

If searching for `Mango___Gall_Midge` again, use the scientific name
*Procontarinia mangiferae* explicitly rather than "gall midge" alone, which
pulls in the whole family across unrelated host plants.

## Known gaps remaining across the 51 classes

Tier 1 (Rice + Groundnut): **complete**, all 7 classes covered.
Tier 2 (Sugarcane + Mango): 4 of 13 done (Anthracnose, Powdery_Mildew,
Healthy, Cutting_Weevil; Bacterial_Canker pending review) — Sugarcane
untouched (0/5), Mango still needs Die_Back, Gall_Midge, Sooty_Mould.
Tier 3 (Cashew, Cassava, Maize, Tomato, Banana): 10 of 31 classes covered.
Cashew untouched (0/5). Cassava still needs Brown_Spot, Healthy,
Green_Mottle. Maize still needs Healthy, Leaf_Blight, Leaf_Spot, Blight,
Common_Rust, Gray_Leaf_Spot. Tomato still needs Healthy, Verticillium_Wilt.
Banana still needs Healthy, Pestalotiopsis.

## Note for the presentation

Two Ghana-specific factsheets uploaded during sourcing (stem borers on
maize, insect pests on tomato) turned out to cover major real-world pests
that aren't represented in the model's class list at all (African maize
stalk borer, tomato leafminer, whitefly). Worth a mention as a separate,
more fundamental limitation than field accuracy on existing classes — see
prior conversation notes.
