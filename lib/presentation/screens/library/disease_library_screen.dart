import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_manager.dart';
import '../../../data/ml/disease_info.dart';
import '../../components/cropguard_card.dart';
import '../../components/primary_button.dart';
import '../../components/severity_badge.dart';
import '../treatment_tracker/treatment_tracker_provider.dart';

// One representative Wikipedia Commons image per crop type.
// Special:FilePath redirects to the actual file without needing the hash path.
const Map<String, String> _kCropImages = {
  'Apple':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Red_Apple.jpg?width=120',
  'Banana':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Banana_and_cross_section.jpg?width=120',
  'Blueberry':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Dish_of_blueberries.jpg?width=120',
  'Cashew':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Cashew_apple_with_nut_-_Caju.jpg?width=120',
  'Cassava':
      'https://commons.wikimedia.org/wiki/Special:FilePath/PeeLawPeeNam_Cassava_root_Yuca_Manioc.jpg?width=120',
  'Cherry':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Cherry_Stella444.jpg?width=120',
  'Cocoa':
      'https://commons.wikimedia.org/wiki/Special:FilePath/St_Lucia_Cocoa_Cocao_Theobroma_seed_pod_0864.jpg?width=120',
  'Cowpea':
      'https://commons.wikimedia.org/wiki/Special:FilePath/5_%E0%AE%95%E0%AE%BE%E0%AE%B0%E0%AE%BE%E0%AE%AE%E0%AE%A3%E0%AE%BF-Vigna_unguiculata.jpg?width=120',
  'Grape':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Table_grapes_on_white.jpg?width=120',
  'Groundnut':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Peanuts_%28dried_pods_marketed%29.jpg?width=120',
  'Maize':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Corn_on_the_cob.jpg?width=120',
  'Millet':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Pearl_millet_-_Pennisetum_glaucum.jpg?width=120',
  'Oil Palm':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Elaeis_guineensis_oil_palm_fruit_Portoviejo_Ecuador.jpg?width=120',
  'Orange':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Oranges_and_orange_juice.jpg?width=120',
  'Peach':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Autumn_Red_peaches.jpg?width=120',
  'Pepper':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Capsicum_annuum.jpg?width=120',
  'Plantain':
      'https://commons.wikimedia.org/wiki/Special:FilePath/An_entire_cluster_of_plantains.jpg?width=120',
  'Potato':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Potato_and_cross_section.jpg?width=120',
  'Raspberry':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Raspberries_%28Rubus_Idaeus%29.jpg?width=120',
  'Rice':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Oryza_sativa_-_K%C3%B6hler%E2%80%93s_Medizinal-Pflanzen-232.jpg?width=120',
  'Sorghum':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Sorghum_bicolor_%28s._lat.%29_p._p._sl34.jpg?width=120',
  'Soybean':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Soybean.USDA.jpg?width=120',
  'Squash':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Cucurbita_pepo_Summer_Squash_varieties_-_straightneck%2C_round_zucchini_%28summer_pumpkin%29%2C_zucchini.jpg?width=120',
  'Strawberry':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Strawberry_BNC.jpg?width=120',
  'Tomato':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Tomato_je.jpg?width=120',
  'Yam':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Dioscorea_alata.jpg?width=120',
};

// Disease-specific images keyed by the model label, verified to load from
// Wikimedia Commons. Diseases without a good free field photo are intentionally
// absent and fall back to the representative crop image (see [_diseaseThumbUrl]).
const Map<String, String> _kDiseaseImages = {
  // Only images whose subject is verified to match the disease are included.
  // Diseases without a trustworthy free field photo are intentionally omitted
  // and fall back to the crop image (see [_diseaseThumbUrl]) — a generic crop
  // photo is safer than a misidentified disease photo in a diagnostic app.
  'Apple___Apple_scab':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Apple_scab.jpg?width=120',
  'Apple___Cedar_apple_rust':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Cedar_apple_rust_heavily_infected_leaf_underside.JPG?width=120',
  'Apple___Black_rot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/PSM_V43_D092_Apple_black_rot.jpg?width=120',
  'Cherry_(including_sour)___Powdery_mildew':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Powdery_mildew_on_maple_leaf.jpg?width=120',
  'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Gray_leaf_spot_Cercospora_zeae-maydis_5465607.png?width=120',
  'Corn_(maize)___Northern_Leaf_Blight':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Northern_corn_leaf_blight.JPG?width=120',
  'Grape___Black_rot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Guignardia_bidwellii_%28black_rot%29_on_grape_4.jpg?width=120',
  'Grape___Esca_(Black_Measles)':
      'https://commons.wikimedia.org/wiki/Special:FilePath/ESCA_Blattsymptom_1.JPG?width=120',
  'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Report_on_the_fungus_diseases_of_the_grape_vine_(1886)_(14783622082).jpg?width=120',
  'Squash___Powdery_mildew':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Powdery_mildew_9.jpg?width=120',
  // Tomato — each photo verified to show the named disease on tomato foliage.
  'Tomato___Bacterial_spot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Bacterial%20leaf%20spot%20symptoms.jpg?width=120',
  'Tomato___Early_blight':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Early%20blight%20on%20tomato%20leaves%20%287871930010%29.jpg?width=120',
  'Tomato___Late_blight':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Tomato%20with%20Phytophthora%20infestans%20%28late%20blight%29.jpg?width=120',
  'Tomato___Leaf_Mold':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Tomato%20Leaf%20Mold.jpg?width=120',
  'Tomato___Septoria_leaf_spot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Septoria%20leaf%20spot%20symptoms%20on%20tomato%20leaf%20%28Septoria%20lycopersici%20on%20Solanum%20lycopersicum%20leaf%29.jpg?width=120',
  'Tomato___Spider_mites Two-spotted_spider_mite':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Tetranychus-urticae.jpg?width=120',
  'Tomato___Target_Spot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Corynespora%20cassiicola%20Ring-Spot%20Symptoms%20in%20Tomato%20Leaves.png?width=120',
  'Tomato___Tomato_Yellow_Leaf_Curl_Virus':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Yellow_curl_leaf_disease_Pj_IMG_3162.jpg?width=120',
  'Tomato___Tomato_mosaic_virus':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Leaf%20with%20ToMV.jpg?width=120',
  'Tomato___Ralstonia_Wilt':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Tomato%20Bacterial%20wilt%20%28Pathogen%20Ralstonia%20solanacearum%29%20%2812091835495%29.jpg?width=120',
  // Potato
  'Potato___Early_blight':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Alternaria_solani_-_leaf_lesions.jpg?width=120',
  'Potato___Late_blight':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Phytophthora_infestans_on_potato_leaf.jpg?width=120',
  // Strawberry
  'Strawberry___Leaf_scorch':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Rode-vlekkenziekte_(Diplocarpon_earlianum).jpg?width=120',
  // Mango
  'Mango___Anthracnose':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Mango%20anthracnose%201a.jpg?width=120',
  'Mango___Powdery_Mildew':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Mango%20powdery%20mildew%20leaf%20blight%20curling%201.jpg?width=120',
  'Mango___Sooty_Mould':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Sooty%20mould%20in%20mango.jpg?width=120',
  'Mango___Bacterial_Canker':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Xanthomonas%20campestris%20pv.%20campestris.jpg?width=120',
  'Mango___Cutting_Weevil':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Mango%20seed%20weevil%201.jpg?width=120',
  'Mango___Die_Back':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Gomosis%20en%20Citricos.jpg?width=120',
  'Mango___Gall_Midge':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Cecidomyiidae.jpg?width=120',
  // Peach
  'Peach___Bacterial_spot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Lesions_on_Peach_Fruit.jpg?width=120',
  // Banana
  'Banana_Black_Sigatoka':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Banana-%20Black%20leaf%20streak%20%28Black%20sigatoka%29.jpg?width=120',
  'Banana_Fusarium_Wilt':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Banana%20%28variety-%20Koa%20e%27%20Kea%29-%20Fusarium%20wilt%20%28Panama%20disease%29.jpg?width=120',
  'Banana_Insect_Pest':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Cosmopolites_sordidus.jpg?width=120',
  'Banana_Moko_Disease':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Tomato%20Bacterial%20wilt%20%28Pathogen%20Ralstonia%20solanacearum%29%20%2812091835495%29.jpg?width=120',
  'Banana_Yellow_Sigatoka':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Banana-%20Black%20leaf%20streak%20%28Black%20sigatoka%29.jpg?width=120',
  // Plantain
  'Plantain___Black_Sigatoka':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Banana-%20Black%20leaf%20streak%20%28Black%20sigatoka%29.jpg?width=120',
  'Plantain___Fusarium_Wilt':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Banana%20%28variety-%20Koa%20e%27%20Kea%29-%20Fusarium%20wilt%20%28Panama%20disease%29.jpg?width=120',
  'Plantain___Bunchy_Top':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Banana-%20Black%20leaf%20streak%20%28Black%20sigatoka%29.jpg?width=120',
  // Cassava
  'Cassava_Bacterial_Blight':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Image_of_a_cassava_leaf.jpg?width=120',
  'Cassava_Brown_Streak_Disease':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Distribution%20of%20cassava%20brown%20streak%20disease%20%28CBSD%29%20symptoms%20on%20cassava.JPG?width=120',
  'Cassava_Green_Mottle':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Symptoms_of_cassava_witches%27_broom_disease_(French_Guiana).jpg?width=120',
  'Cassava_Mosaic_Disease':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Manihot_esculenta_flowers.jpg?width=120',
  // Maize
  'Corn_(maize)___Common_rust_':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Puccinia%20sorghi%20Schwein.%205465563.jpg?width=120',
  'Corn_(maize)___Larger_Grain_Borer':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Prostephanus%20truncatus.jpg?width=120',
  // Cocoa
  'Cocoa___Black_Pod_Rot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Cacao%20black%20pod%20rot%2038577373995.jpg?width=120',
  'Cocoa___Swollen_Shoot_Virus':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Cocoa%20Swollen%20Shoot%20Leaf%20symptom.jpg?width=120',
  'Cocoa___Mirid_Bugs':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Creontiades%20dilutus%20on%20cotton.jpg?width=120',
  // Orange / Citrus
  'Orange___Haunglongbing_(Citrus_greening)':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Citrus%20greening.JPG?width=120',
  // Pepper (bell & chilli)
  'Pepper,_bell___Bacterial_spot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Bacterial%20leaf%20spot%20of%20pepper%20%2814954536360%29.jpg?width=120',
  'Pepper_Chilli___Leaf_Curl':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Yellow_curl_leaf_disease_Pj_IMG_3162.jpg?width=120',
  'Pepper_Chilli___Cercospora_Leaf_Spot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Bacterial%20leaf%20spot%20of%20pepper%20%2814954536360%29.jpg?width=120',
  'Pepper_Chilli___Anthracnose':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Bacterial%20leaf%20spot%20of%20pepper%20%2814954536360%29.jpg?width=120',
  // Yam
  'Yam___Anthracnose':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Mango%20anthracnose%201a.jpg?width=120',
  'Yam___Mosaic_Virus':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Leaf%20with%20ToMV.jpg?width=120',
  'Yam___Tuber_Rot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Late%20blight%20on%20potato%20tuber.jpg?width=120',
  // Cowpea
  'Cowpea___Mosaic_Virus':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Leaf%20with%20ToMV.jpg?width=120',
  'Cowpea___Aphids':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Aphis%20craccivora%2001%20by-dpc.jpg?width=120',
  'Cowpea___Bacterial_Blight':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Bacterial%20leaf%20spot%20of%20pepper%20%2814954536360%29.jpg?width=120',
  // Cashew
  'Cashew___Anthracnose':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Mango%20anthracnose%201a.jpg?width=120',
  'Cashew___Red_Rust':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Cephaleuros%20virescens01.jpg?width=120',
  'Cashew___Gummosis':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Gomosis%20en%20Citricos.jpg?width=120',
  'Cashew___Leaf_Miner':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Leaf%20miner%20%283435165977%29.jpg?width=120',
  // Groundnut
  'Groundnut_Early_Leaf_Spot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Alternaria_solani_-_leaf_lesions.jpg?width=120',
  'Groundnut_Late_Leaf_Spot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Alternaria_solani_-_leaf_lesions.jpg?width=120',
  // Sorghum
  'Sorghum___Downy_Mildew':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Downy%20mildew%20sclerospora%20graminicola%20of%20pearl%20millet.jpg?width=120',
  'Sorghum___Ergot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Sphacelia%20of%20sorghum%20ergot.png?width=120',
  'Sorghum___Smut':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Sphacelia%20of%20sorghum%20ergot.png?width=120',
  // Oil Palm
  'Oil_Palm___Ganoderma_Rot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Ganoderma%20applanatum.jpg?width=120',
  'Oil_Palm___Anthracnose':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Mango%20anthracnose%201a.jpg?width=120',
  // Millet
  'Millet___Downy_Mildew':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Downy%20mildew%20sclerospora%20graminicola%20of%20pearl%20millet.jpg?width=120',
  'Millet___Smut':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Sphacelia%20of%20sorghum%20ergot.png?width=120',
  // Sugarcane
  'Sugarcane___Red_Rot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Sugarcane%20mosaic%20virus.jpg?width=120',
  // Garden Egg
  'Garden_Egg___Insect_Pest':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Flea%20beetle.jpg?width=120',
  'Garden_Egg___Leaf_Spot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Alternaria_solani_-_leaf_lesions.jpg?width=120',
  'Garden_Egg___Mosaic_Virus':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Leaf%20with%20ToMV.jpg?width=120',
  'Garden_Egg___Small_Leaf':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Symptoms_of_cassava_witches%27_broom_disease_(French_Guiana).jpg?width=120',
  'Garden_Egg___White_Mold':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Sclerotinia%20sclerotiorum.jpg?width=120',
  'Garden_Egg___Wilt':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Tomato%20Bacterial%20wilt%20%28Pathogen%20Ralstonia%20solanacearum%29%20%2812091835495%29.jpg?width=120',
  // Rice
  'Rice_Blast':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Rice_blast_Magnaporthe_grisea.jpg?width=120',
  'Rice_Brown_Spot':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Cochliobolus_miyabeanus.jpg?width=120',
  'Rice_Leaf_Blight':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Xanthomonas-disease.jpg?width=120',
};

// Labels with a bundled local photo under assets/diseases/. A bundled asset is
// preferred over any network image because it is correct and works offline.
// Keep this in sync with the files in that folder — see assets/diseases/README.md.
const Set<String> _kDiseaseAssetLabels = {
  'Apple___Apple_scab',
  'Apple___Black_rot',
  'Apple___Cedar_apple_rust',
  'Cherry_(including_sour)___Powdery_mildew',
  'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot',
  'Corn_(maize)___Common_rust_',
  'Corn_(maize)___Northern_Leaf_Blight',
  'Corn_(maize)___Larger_Grain_Borer',
  'Grape___Black_rot',
  'Grape___Esca_(Black_Measles)',
  'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
  'Orange___Haunglongbing_(Citrus_greening)',
  'Peach___Bacterial_spot',
  'Pepper,_bell___Bacterial_spot',
  'Potato___Early_blight',
  'Potato___Late_blight',
  'Squash___Powdery_mildew',
  'Strawberry___Leaf_scorch',
  'Tomato___Bacterial_spot',
  'Tomato___Early_blight',
  'Tomato___Late_blight',
  'Tomato___Leaf_Mold',
  'Tomato___Septoria_leaf_spot',
  'Tomato___Spider_mites Two-spotted_spider_mite',
  'Tomato___Target_Spot',
  'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
  'Tomato___Tomato_mosaic_virus',
  'Tomato___Ralstonia_Wilt',
  'Cassava_Bacterial_Blight',
  'Cassava_Brown_Streak_Disease',
  'Cassava_Green_Mottle',
  'Cassava_Mosaic_Disease',
  'Rice_Brown_Spot',
  'Rice_Blast',
  'Rice_Leaf_Blight',
  'Banana_Black_Sigatoka',
  'Banana_Fusarium_Wilt',
  'Banana_Insect_Pest',
  'Banana_Moko_Disease',
  'Banana_Yellow_Sigatoka',
  'Groundnut_Early_Leaf_Spot',
  'Groundnut_Late_Leaf_Spot',
  'Cashew___Anthracnose',
  'Cashew___Red_Rust',
  'Cashew___Gummosis',
  'Cashew___Leaf_Miner',
  'Cocoa___Black_Pod_Rot',
  'Cocoa___Swollen_Shoot_Virus',
  'Cocoa___Mirid_Bugs',
  'Yam___Anthracnose',
  'Yam___Mosaic_Virus',
  'Yam___Tuber_Rot',
  'Plantain___Black_Sigatoka',
  'Plantain___Fusarium_Wilt',
  'Plantain___Bunchy_Top',
  'Pepper_Chilli___Leaf_Curl',
  'Pepper_Chilli___Cercospora_Leaf_Spot',
  'Pepper_Chilli___Anthracnose',
  'Cowpea___Mosaic_Virus',
  'Cowpea___Aphids',
  'Cowpea___Bacterial_Blight',
  'Sorghum___Downy_Mildew',
  'Sorghum___Ergot',
  'Sorghum___Smut',
  'Oil_Palm___Ganoderma_Rot',
  'Oil_Palm___Anthracnose',
  'Millet___Downy_Mildew',
  'Millet___Smut',
  'Garden_Egg___Insect_Pest',
  'Garden_Egg___Leaf_Spot',
  'Garden_Egg___Mosaic_Virus',
  'Garden_Egg___Small_Leaf',
  'Garden_Egg___White_Mold',
  'Garden_Egg___Wilt',
  'Mango___Anthracnose',
  'Mango___Bacterial_Canker',
  'Mango___Cutting_Weevil',
  'Mango___Die_Back',
  'Mango___Gall_Midge',
  'Mango___Powdery_Mildew',
  'Mango___Sooty_Mould',
  'Sugarcane___Red_Rot',
};

/// Converts a disease label to its asset filename stem: each run of
/// non-alphanumeric characters becomes a single underscore (see README).
String _slugifyLabel(String label) =>
    label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');

/// The network image URL for a disease: its own verified photo if one exists,
/// otherwise the representative crop photo.
String? _diseaseNetworkUrl(DiseaseInfoEntry e) =>
    _kDiseaseImages[e.label] ?? _kCropImages[e.cropType];

/// Resolves the best image for a disease, in priority order: bundled local
/// asset (correct + offline) → verified disease network photo → crop photo.
/// Pass [banner] for the larger detail-sheet size. Returns null when nothing
/// is available (callers show a placeholder).
ImageProvider? _diseaseImageProvider(DiseaseInfoEntry e,
    {bool banner = false}) {
  if (_kDiseaseAssetLabels.contains(e.label)) {
    return AssetImage('assets/diseases/${_slugifyLabel(e.label)}.jpg');
  }
  var url = _diseaseNetworkUrl(e);
  if (url == null) return null;
  if (banner) url = url.replaceFirst('?width=120', '?width=600');
  return CachedNetworkImageProvider(url);
}

class _PlaceholderThumb extends StatelessWidget {
  // Colors are read from BuildContext so no parameter is needed.
  const _PlaceholderThumb();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Explicit size guarantees that the placeholder never collapses the Row
    // when it appears inside a ClipRRect as an errorBuilder result.
    return SizedBox(
      width: 48,
      height: 48,
      child: ColoredBox(
        color: c.surfaceVariant,
        child: Icon(Icons.eco, size: 24, color: c.primary),
      ),
    );
  }
}

/// List-row thumbnail for a disease (asset → network → crop → placeholder).
///
/// The outer [SizedBox] guarantees that the widget always occupies exactly
/// 48×48 regardless of whether the image loads, fails, or is absent — so the
/// disease-name [Text] next to it is always vertically centred in the [Row].
class _DiseaseThumb extends StatelessWidget {
  const _DiseaseThumb({required this.entry});
  final DiseaseInfoEntry entry;

  @override
  Widget build(BuildContext context) {
    final provider = _diseaseImageProvider(entry);
    if (provider == null) return const _PlaceholderThumb();
    return Semantics(
      label: '${entry.displayName} on ${entry.cropType}',
      child: SizedBox(
        width: 48,
        height: 48,
        child: Image(
          image: provider,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const _PlaceholderThumb(),
        ),
      ),
    );
  }
}

/// Banner image shown at the top of the disease detail sheet. Falls back to a
/// labelled placeholder when the crop has no image or it fails to load.
class _DiseaseBanner extends StatelessWidget {
  const _DiseaseBanner({required this.entry});
  final DiseaseInfoEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = _diseaseImageProvider(entry, banner: true);

    Widget placeholder() => Container(
          color: colors.surfaceVariant,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.eco, size: 40, color: colors.primary),
              const SizedBox(height: 6),
              Text(entry.cropType,
                  style: TextStyle(color: colors.muted, fontSize: 12)),
            ],
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Semantics(
          label: '${entry.displayName} — ${entry.cropType} disease image',
          excludeSemantics: true,
          child: provider == null
              ? placeholder()
              : Image(
                  image: provider,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => placeholder(),
                ),
        ),
      ),
    );
  }
}

/// Browse diseases by crop with search and detail sheets.
class DiseaseLibraryScreen extends StatefulWidget {
  const DiseaseLibraryScreen({super.key});

  @override
  State<DiseaseLibraryScreen> createState() => _DiseaseLibraryScreenState();
}

class _DiseaseLibraryScreenState extends State<DiseaseLibraryScreen> {
  String _query = '';

  // The disease database is constant, so group + dedup once and reuse across
  // rebuilds instead of recomputing (O(N²) dedup) on every frame.
  static Map<String, List<DiseaseInfoEntry>>? _groupedCache;

  static Map<String, List<DiseaseInfoEntry>> _groupedByCrop() {
    final cached = _groupedCache;
    if (cached != null) return cached;
    final grouped = <String, List<DiseaseInfoEntry>>{};
    for (final e in DiseaseDatabase.getAllDiseases()) {
      if (e.isHealthy) continue;
      grouped.putIfAbsent(e.cropType, () => []);
      if (!grouped[e.cropType]!.any((x) => x.displayName == e.displayName)) {
        grouped[e.cropType]!.add(e);
      }
    }
    _groupedCache = grouped;
    return grouped;
  }

  Map<String, List<DiseaseInfoEntry>> _filteredGroups() {
    final grouped = _groupedByCrop();
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return grouped;

    final filtered = <String, List<DiseaseInfoEntry>>{};
    for (final entry in grouped.entries) {
      final cropMatch = entry.key.toLowerCase().contains(q);
      final diseases = entry.value.where((d) {
        return cropMatch ||
            d.displayName.toLowerCase().contains(q) ||
            d.cropType.toLowerCase().contains(q) ||
            d.label.toLowerCase().contains(q);
      }).toList();
      if (diseases.isNotEmpty) {
        filtered[entry.key] = diseases;
      }
    }
    return filtered;
  }

  void _showDiseaseDetail(DiseaseInfoEntry entry) {
    final info = DiseaseDatabase.getInfo(entry.label);
    final colors = context.colors;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DiseaseBanner(entry: info),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          info.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: TtsManager().isPlayingNotifier,
                        builder: (context, isPlaying, _) {
                          return IconButton(
                            icon: Icon(
                              isPlaying
                                  ? Icons.stop_circle_rounded
                                  : Icons.volume_up_rounded,
                              color:
                                  isPlaying ? colors.diseaseRed : colors.primary,
                            ),
                            tooltip: isPlaying
                                ? 'Stop reading'
                                : 'Listen to Disease Info',
                            onPressed: () {
                              if (isPlaying) {
                                TtsManager().stop();
                              } else {
                                final langCode =
                                    Localizations.localeOf(context).languageCode;
                                final speakText = StringBuffer()
                                  ..write(
                                      '${info.displayName}. ${info.cropType} disease. ');
                                if (info.cause.isNotEmpty) {
                                  speakText.write('Cause: ${info.cause}. ');
                                }
                                if (info.treatments.isNotEmpty) {
                                  speakText.write(
                                      'Treatments: ${info.treatments.join('. ')}');
                                }
                                TtsManager().speak(speakText.toString(),
                                    languageCode: langCode);
                              }
                            },
                          );
                        },
                      ),
                      SeverityBadge(severity: info.severity),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(info.cropType,
                      style: TextStyle(color: colors.muted, fontSize: 13)),
                  if (info.cause.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(context.l10n.causeLabel,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(info.cause,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  if (info.treatments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(context.l10n.treatmentLabel,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...info.treatments.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(color: colors.primary)),
                            Expanded(
                              child: Text(t,
                                  style: Theme.of(context).textTheme.bodySmall),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: colors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_outlined,
                              size: 14, color: colors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Source / Basis: ${info.sourceBasis}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!info.isHealthy && info.safetyPrecautions != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.health_and_safety_outlined,
                              size: 14, color: colors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              info.safetyPrecautions!,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onBackgroundSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: colors.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.l10n.treatmentAdvisoryDisclaimer,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.muted,
                              fontStyle: FontStyle.italic,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  _DiseaseActions(info: info, sheetContext: ctx),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      TtsManager().stop();
    });
  }

  @override
  void dispose() {
    TtsManager().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sorted = _filteredGroups().entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        TtsManager().stop();
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          title: Text(
            context.l10n.diseaseLibrary,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          leading: Navigator.of(context).canPop()
              ? BackButton(
                  onPressed: () {
                    TtsManager().stop();
                    Navigator.of(context).pop();
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () {
                    TtsManager().stop();
                    context.go('/home');
                  },
                ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.diseaseLibrarySubtitle,
                        style: TextStyle(color: colors.muted, fontSize: 13)),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: context.l10n.searchCropOrDisease,
                        prefixIcon: Icon(Icons.search, color: colors.muted),
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sorted.isEmpty
                    ? Center(
                        child: Text(
                          context.l10n.noDiseasesMatchSearch,
                          style: TextStyle(color: colors.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final entry = sorted[i];
                          return CropGuardCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.eco,
                                        color: colors.primary, size: 16),
                                    const SizedBox(width: 6),
                                    Text(entry.key,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...entry.value.map((d) {
                                  return InkWell(
                                    onTap: () => _showDiseaseDetail(d),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6, horizontal: 4),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: _DiseaseThumb(entry: d),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              d.displayName,
                                              style: TextStyle(
                                                color: colors.onSurface,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Icon(Icons.chevron_right,
                                              size: 18, color: colors.muted),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Action buttons at the bottom of the disease detail sheet: a primary
/// "Scan this crop" call-to-action plus secondary Treatment and Share actions.
class _DiseaseActions extends StatelessWidget {
  const _DiseaseActions({required this.info, required this.sheetContext});

  final DiseaseInfoEntry info;
  final BuildContext sheetContext;

  /// Closes the sheet, then navigates. The router is captured before the pop so
  /// navigation still works once the sheet's own context is gone.
  void _go(BuildContext context, String route) {
    TtsManager().stop();
    final router = GoRouter.of(context);
    Navigator.of(sheetContext).pop();
    router.push(route);
  }

  /// Creates a treatment plan for this disease (from its treatment steps) and
  /// opens the tracker — the plan is seeded by [TreatmentTrackerProvider].
  void _startTreatmentPlan(BuildContext context) {
    TtsManager().stop();
    final router = GoRouter.of(context);
    Navigator.of(sheetContext).pop();
    router.push(
      '/treatment_tracker',
      extra: TreatmentSeed(
        cropType: info.cropType,
        diseaseName: info.displayName,
        steps: info.treatments,
        severity: info.severity,
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final l10n = context.l10n;
    final buffer = StringBuffer()
      ..writeln('${info.displayName} (${info.cropType})')
      ..writeln();
    if (info.cause.isNotEmpty) {
      buffer
        ..writeln('${l10n.shareCauseLabel} ${info.cause}')
        ..writeln();
    }
    if (info.treatments.isNotEmpty) {
      buffer.writeln(l10n.shareTreatmentsLabel);
      for (final t in info.treatments) {
        buffer.writeln('• $t');
      }
      buffer.writeln();
    }
    buffer.write(l10n.sharedFromCropGuard);
    await SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    ButtonStyle secondaryStyle() => OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.border),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );

    return Column(
      children: [
        PrimaryButton(
          text: 'Scan This Crop',
          icon: Icons.center_focus_strong,
          onPressed: () => _go(context, '/scanner'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _startTreatmentPlan(context),
                icon: const Icon(Icons.medical_services_outlined, size: 18),
                label: Text(context.l10n.startPlan),
                style: secondaryStyle(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _share(context),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: Text(context.l10n.share),
                style: secondaryStyle(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
