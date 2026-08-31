import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn
import datetime
import os

def set_cell_background(cell, fill_hex):
    """Sets background color of a table cell."""
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    """Sets cell padding in twips."""
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = OxmlElement('w:tcMar')
    for m, val in [('top', top), ('bottom', bottom), ('left', left), ('right', right)]:
        node = OxmlElement(f'w:{m}')
        node.set(qn('w:w'), str(val))
        node.set(qn('w:type'), 'dxa')
        tcMar.append(node)
    tcPr.append(tcMar)

def add_callout(doc, text, title="NOTE / IMPLEMENTATION HIGHLIGHT", border_color="2E7D32", bg_color="F1F8E9"):
    """Adds a callout block to the document."""
    tbl = doc.add_table(rows=1, cols=1)
    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    cell = tbl.cell(0, 0)
    set_cell_background(cell, bg_color)
    set_cell_margins(cell, top=140, bottom=140, left=200, right=200)
    
    tcPr = cell._tc.get_or_add_tcPr()
    borders = parse_xml(
        f'<w:tcBorders {nsdecls("w")}>\n'
        f'  <w:left w:val="single" w:sz="24" w:space="0" w:color="{border_color}"/>\n'
        f'  <w:top w:val="none"/>\n'
        f'  <w:right w:val="none"/>\n'
        f'  <w:bottom w:val="none"/>\n'
        f'</w:tcBorders>'
    )
    tcPr.append(borders)
    
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(2)
    run_title = p.add_run(f"[{title}]\n")
    run_title.bold = True
    run_title.font.size = Pt(10)
    run_title.font.color.rgb = RGBColor(0x1B, 0x5E, 0x20)
    
    run_text = p.add_run(text)
    run_text.font.size = Pt(10)
    run_text.font.color.rgb = RGBColor(0x37, 0x47, 0x4F)
    doc.add_paragraph()

def style_table(table, header_bg="1B5E20", alt_bg="F9FBE7"):
    """Applies modern clean styling to a docx table."""
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i, row in enumerate(table.rows):
        # Prevent row from splitting across pages
        trPr = row._tr.get_or_add_trPr()
        trPr.append(parse_xml(f'<w:cantSplit {nsdecls("w")}/>'))
        
        # Header repeat on every page
        if i == 0:
            trPr.append(parse_xml(f'<w:tblHeader {nsdecls("w")}/>'))
            
        for cell in row.cells:
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            set_cell_margins(cell, top=120, bottom=120, left=150, right=150)
            if i == 0:
                set_cell_background(cell, header_bg)
                for p in cell.paragraphs:
                    p.paragraph_format.space_before = Pt(4)
                    p.paragraph_format.space_after = Pt(4)
                    for r in p.runs:
                        r.bold = True
                        r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
                        r.font.size = Pt(9.5)
            else:
                if i % 2 == 1:
                    set_cell_background(cell, "FFFFFF")
                else:
                    set_cell_background(cell, alt_bg)
                for p in cell.paragraphs:
                    p.paragraph_format.space_before = Pt(3)
                    p.paragraph_format.space_after = Pt(3)
                    for r in p.runs:
                        r.font.size = Pt(9)
                        r.font.color.rgb = RGBColor(0x26, 0x32, 0x38)

def create_report():
    doc = Document()
    
    # ── Page Margins ────────────────────────────────────────────────────────
    for section in doc.sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)
        section.header_distance = Inches(0.5)
        section.footer_distance = Inches(0.5)
        
        # Header & Footer setup
        header = section.header
        hp = header.paragraphs[0]
        hp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        hrun = hp.add_run("CropGuard AI — Final-Year Project Technical Documentation")
        hrun.font.size = Pt(8.5)
        hrun.font.color.rgb = RGBColor(0x78, 0x90, 0x9C)
        
        footer = section.footer
        fp = footer.paragraphs[0]
        fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        frun = fp.add_run("Department of Computer Science & Engineering | Confidential Academic Report")
        frun.font.size = Pt(8.5)
        frun.font.color.rgb = RGBColor(0x90, 0xA4, 0xAE)

    # ── Styles Setup ────────────────────────────────────────────────────────
    normal_style = doc.styles['Normal']
    normal_style.font.name = 'Segoe UI'
    normal_style.font.size = Pt(10.5)
    normal_style.font.color.rgb = RGBColor(0x26, 0x32, 0x38)
    normal_style.paragraph_format.line_spacing = 1.15
    normal_style.paragraph_format.space_after = Pt(6)

    # =========================================================================
    # 1. TITLE PAGE
    # =========================================================================
    p_pre = doc.add_paragraph()
    p_pre.paragraph_format.space_before = Pt(30)
    
    p_title = doc.add_paragraph()
    p_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_title = p_title.add_run("CROPGUARD AI\n")
    r_title.bold = True
    r_title.font.size = Pt(28)
    r_title.font.color.rgb = RGBColor(0x1B, 0x5E, 0x20)
    
    r_sub = p_title.add_run("An Edge-AI Powered Mobile Agricultural Diagnostic & Disease Outbreak Surveillance System for Sub-Saharan Smallholder Farmers\n")
    r_sub.font.size = Pt(14)
    r_sub.font.italic = True
    r_sub.font.color.rgb = RGBColor(0x38, 0x8E, 0x3C)
    
    p_div = doc.add_paragraph()
    p_div.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_div = p_div.add_run("―" * 35)
    r_div.font.color.rgb = RGBColor(0x81, 0xC7, 0x84)
    
    p_desc = doc.add_paragraph()
    p_desc.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_desc.paragraph_format.space_before = Pt(20)
    p_desc.paragraph_format.space_after = Pt(60)
    r_desc = p_desc.add_run(
        "A Comprehensive Technical Project Report Submitted in Partial Fulfillment of the\n"
        "Requirements for the Degree of Bachelor of Science in Computer Science / Software Engineering\n"
    )
    r_desc.font.size = Pt(11)
    r_desc.font.color.rgb = RGBColor(0x54, 0x6E, 0x7A)
    
    # Author Card Table
    auth_table = doc.add_table(rows=6, cols=2)
    auth_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    auth_data = [
        ("Candidate Name:", "Kwame Yeboah"),
        ("Student ID / Index:", "FYP-CS-2026-088"),
        ("Programme / Dept:", "Department of Computer Science & Engineering"),
        ("Faculty / Institution:", "Faculty of Physical & Applied Sciences"),
        ("Project Supervisor:", "Prof. / Dr. Lead Academic Supervisor"),
        ("Date of Submission:", "August 2026 / Academic Year 2025–2026")
    ]
    for idx, (label, val) in enumerate(auth_data):
        cell_lbl = auth_table.cell(idx, 0)
        cell_val = auth_table.cell(idx, 1)
        cell_lbl.paragraphs[0].add_run(label).bold = True
        cell_lbl.paragraphs[0].runs[0].font.size = Pt(10)
        cell_lbl.paragraphs[0].runs[0].font.color.rgb = RGBColor(0x1B, 0x5E, 0x20)
        cell_val.paragraphs[0].add_run(val)
        cell_val.paragraphs[0].runs[0].font.size = Pt(10)
        set_cell_background(cell_lbl, "F1F8E9")
        set_cell_background(cell_val, "FAFAFA")
        set_cell_margins(cell_lbl, top=60, bottom=60, left=100, right=100)
        set_cell_margins(cell_val, top=60, bottom=60, left=100, right=100)
    
    doc.add_page_break()

    # Helper for adding formatted section headings
    def add_h1(text):
        h = doc.add_heading(level=1)
        h.paragraph_format.space_before = Pt(18)
        h.paragraph_format.space_after = Pt(6)
        r = h.add_run(text)
        r.bold = True
        r.font.size = Pt(18)
        r.font.color.rgb = RGBColor(0x1B, 0x5E, 0x20)
        return h

    def add_h2(text):
        h = doc.add_heading(level=2)
        h.paragraph_format.space_before = Pt(12)
        h.paragraph_format.space_after = Pt(4)
        r = h.add_run(text)
        r.bold = True
        r.font.size = Pt(13.5)
        r.font.color.rgb = RGBColor(0x2E, 0x7D, 0x32)
        return h

    def add_h3(text):
        h = doc.add_heading(level=3)
        h.paragraph_format.space_before = Pt(8)
        h.paragraph_format.space_after = Pt(2)
        r = h.add_run(text)
        r.bold = True
        r.font.size = Pt(11.5)
        r.font.color.rgb = RGBColor(0x38, 0x8E, 0x3C)
        return h

    # =========================================================================
    # 2. PROJECT OVERVIEW
    # =========================================================================
    add_h1("1. Project Overview")
    
    add_h2("1.1 Executive Summary")
    doc.add_paragraph(
        "CropGuard AI is a state-of-the-art, offline-first, multimodal agricultural intelligence system engineered "
        "specifically for smallholder farmers, extension officers, and agricultural researchers in West Africa and "
        "sub-Saharan Africa. The system delivers instant, on-device crop leaf disease identification using deeply quantized "
        "TensorFlow Lite convolutional neural networks, coupled with secondary multimodal cloud AI validation via Google Gemini 1.5 Flash. "
        "To dismantle entrenched barriers of rural illiteracy and language isolation, CropGuard integrates native Ghanaian language speech recognition (ASR v3) "
        "and voice synthesis (TTS v2) in Twi, Ewe, and Dagbani powered by Khaya AI (GhanaNLP)."
    )
    
    add_h2("1.2 Problem Statement & Agricultural Context")
    doc.add_paragraph(
        "Agriculture accounts for over 20% of Ghana's GDP and employs over 44% of the national workforce. However, smallholder farmers "
        "suffer annual yield losses ranging between 30% and 50% due to unmitigated plant pathogens such as Cocoa Black Pod (Phytophthora palmivora), "
        "Cassava Mosaic Disease, Maize Fall Armyworm damage, and Tomato Late Blight. In rural farming communities, the ratio of agricultural "
        "extension agents to farmers exceeds 1:1,500, leading to delayed diagnoses, inappropriate agrochemical misapplication, soil poisoning, "
        "and catastrophic financial loss."
    )
    doc.add_paragraph(
        "Existing mobile agricultural tools fail in this operating environment due to three fatal constraints: (1) heavy reliance on permanent, "
        "high-bandwidth cloud connectivity that does not exist in rural farms; (2) rigid monolingual (English) interfaces inaccessible to non-literate farmers; "
        "and (3) lack of localized epidemiological tracking, preventing early quarantine of regional outbreaks."
    )
    
    add_h2("1.3 Project Objectives")
    doc.add_paragraph("The technical and practical objectives of CropGuard AI comprise:")
    objs = [
        ("Sub-Second On-Device Inference: ", "Deploy an optimized MobileNetV2-derived architecture running locally via TensorFlow Lite to achieve classification across 51 distinct crop health classes in under 120ms without internet access."),
        ("Multi-Tier Hybrid Diagnostic Pipeline: ", "Combine local on-device neural classification with soft-voting ensemble heuristics and an authenticated fallback to Google Gemini 1.5 Flash Multimodal Cloud AI for low-confidence or rare anomalies."),
        ("Indigenous Language Accessibility: ", "Integrate Automatic Speech Recognition (ASR v3) and Text-to-Speech (TTS v2) for Ghanaian languages (Twi, Ewe, Dagbani) to enable hands-free voice notes and spoken treatment advisories."),
        ("Real-Time Epidemiological Geospatial Intelligence: ", "Implement an interactive outbreak map aggregating anonymized disease occurrences into weighted regional hotspots with automated push-notification alerts for adjacent farms."),
        ("Resilient Offline-First Synchronization: ", "Implement a conflict-free SQLite pending synchronization queue backed by Firebase Cloud Firestore, automatically flushing when telemetry indicates network restoration.")
    ]
    for title, desc in objs:
        p = doc.add_paragraph(style='List Bullet')
        r_t = p.add_run(title)
        r_t.bold = True
        p.add_run(desc)

    add_callout(
        doc,
        "CropGuard AI bridges the critical gap between high-end Deep Learning research and grassroots smallholder farming reality "
        "by combining zero-latency edge inference with localized vernacular audio interfaces.",
        title="CORE INNOVATION PILLAR"
    )

    # =========================================================================
    # 3. TECHNOLOGIES USED
    # =========================================================================
    add_h1("2. Technologies Used & Implementation Rationale")
    doc.add_paragraph(
        "Every technology incorporated into CropGuard AI was selected to satisfy stringent performance, security, offline reliability, "
        "and cross-platform maintainability standards. Table 2.1 details the full technology stack utilized across the codebase."
    )
    
    tech_table = doc.add_table(rows=1, cols=4)
    tech_table.rows[0].cells[0].paragraphs[0].text = "Technology / Library"
    tech_table.rows[0].cells[1].paragraphs[0].text = "Category"
    tech_table.rows[0].cells[2].paragraphs[0].text = "Usage in Codebase"
    tech_table.rows[0].cells[3].paragraphs[0].text = "Architectural Justification"
    
    tech_data = [
        ("Flutter 3.x / Dart 3.x", "Client Framework", "lib/ (Full App UI, State, Domain)", "Cross-platform high-performance rendering engine with single-codebase parity for Android & iOS."),
        ("TensorFlow Lite (tflite_flutter)", "Edge ML Engine", "lib/data/ml/crop_disease_classifier.dart", "Hardware-accelerated C++ TFLite runtime enabling 51-class on-device inferencing without network."),
        ("Google Gemini 1.5 Flash", "Cloud Multimodal AI", "functions/index.js & gemini_cloud_ai_service.dart", "Multimodal secondary diagnostic opinion when on-device confidence drops below 65%."),
        ("Firebase Cloud Firestore", "Cloud NoSQL DB", "lib/data/repositories/ & functions/", "Real-time reactive document store syncing outbreaks, user profiles, community posts, and trust metrics."),
        ("SQLite / sqflite", "Embedded Local DB", "lib/data/local/database_helper.dart", "ACID-compliant local storage supporting offline scans, treatment trackers, and sync queues."),
        ("Khaya AI (GhanaNLP)", "Vernacular NLP/Audio", "ghana_nlp_service.dart & functions/index.js", "Proprietary African language API delivering ASR v3 and TTS v2 for Twi, Ewe, and Dagbani."),
        ("Firebase Cloud Functions v2", "Serverless Backend", "functions/index.js (Node.js 20)", "Secure authenticated proxy layer keeping subscription keys and Gemini API keys hidden in Secret Manager."),
        ("OpenStreetMap / flutter_map", "Geospatial Rendering", "lib/presentation/screens/outbreak_map/", "Zero-cost, tile-based interactive map displaying outbreak clusters without Google Maps billing lock-in."),
        ("Open-Meteo REST API", "Agrometeorology", "lib/data/repositories/weather_repository_impl.dart", "Hyperlocal temperature, humidity, and rainfall forecasts used to compute localized disease risk indices."),
        ("WorkManager", "Background Execution", "lib/core/utils/background_tasks.dart", "Android WorkManager / iOS Background App Refresh triggering periodic sync and outbreak telemetry."),
        ("flutter_local_notifications", "Push Notifications", "lib/core/utils/notification_helper.dart", "Delivers background disease outbreak alerts and treatment reminders to farmers."),
        ("audioplayers / record", "Audio I/O", "lib/core/utils/tts_manager.dart & voice_dictation_button.dart", "High-fidelity microphone recording (16kHz PCM WAV) and native playback of synthesized speech."),
        ("Provider 6.x", "State Management", "lib/presentation/screens/*/*_provider.dart", "Lightweight, reactive, predictable dependency-injected state management following Flutter best practices.")
    ]
    for item in tech_data:
        row = tech_table.add_row()
        for idx, text in enumerate(item):
            row.cells[idx].paragraphs[0].text = text
    style_table(tech_table)

    # =========================================================================
    # 4. SYSTEM ARCHITECTURE
    # =========================================================================
    add_h1("3. System Architecture & Communication Model")
    doc.add_paragraph(
        "CropGuard AI implements a robust 3-Tier Edge-Hybrid Architecture designed around the principle of Local-First Operation. "
        "All critical diagnostic and operational workflows are capable of executing in a completely network-isolated state, "
        "with opportunistic background synchronization when network connectivity becomes available."
    )
    
    add_h2("3.1 Architectural Decomposition")
    doc.add_paragraph(
        "The architecture separates responsibilities into three distinct physical and logical layers:\n"
        "1. Edge Client Tier (Flutter / Dart): Hosts presentation screens, Provider controllers, SQLite local database, Image Quality Analyzer, "
        "and the TensorFlow Lite inference runtime.\n"
        "2. Secure Serverless Backend Proxy Tier (Firebase Cloud Functions v2 / Node.js 20): Acts as an authenticated gatekeeper using Firebase App Check "
        "and Auth Tokens, communicating with GCP Secret Manager to securely proxy external AI requests without exposing master subscription keys in the mobile binary.\n"
        "3. Cloud Infrastructure & Third-Party Service Tier: Encompasses Cloud Firestore, Cloud Storage, Google Gemini Multimodal APIs, Khaya AI Language APIs, "
        "and Open-Meteo Weather APIs."
    )
    
    # ASCII Architecture Diagram Callout
    arch_diagram = (
        "+---------------------------------------------------------------------------------------+\n"
        "|                             CLIENT EDGE LAYER (FLUTTER / DART)                         |\n"
        "|  +------------------------+  +------------------------+  +--------------------------+ |\n"
        "|  |  UI Presentation &     |  | TFLite Edge Inference  |  | Local SQLite Database    | |\n"
        "|  |  Provider State (MVVM) |  | (MobileNetV2 51-Class) |  | (Scans, Sync Queue, DDL) | |\n"
        "|  +-----------+------------+  +-----------+------------+  +------------+-------------+ |\n"
        "+--------------|---------------------------|----------------------------|---------------+\n"
        "               | (HTTPS / Encrypted Auth)  | (Local Fallback)           | (Sync Flush)   \n"
        "+--------------v---------------------------v----------------------------v---------------+\n"
        "|                    SECURE BACKEND PROXY (FIREBASE CLOUD FUNCTIONS v2)                 |\n"
        "|  - analyzeCropWithGemini   - verifyOutbreak   - synthesizeGhanaNlp (TTS v2)           |\n"
        "|  - transcribeGhanaNlp (ASR v3)   - translateGhanaNlp (v2)   - syncData                |\n"
        "|  - Secret Manager Key Access (Zero Credentials in Client) - Rate Limiter & Sanitizer  |\n"
        "+--------------+---------------------------+----------------------------+---------------+\n"
        "               |                           |                            |                \n"
        "+--------------v------------+  +-----------v------------+  +------------v-------------+ |\n"
        "| Cloud Firestore & Storage |  | Google Gemini 1.5 Flash |  | Khaya AI Platform        | |\n"
        "| (NoSQL Docs & Image URLs) |  | (Multimodal Fallback)  |  | (ASR v3, TTS v2, Trans v2)| |\n"
        "+---------------------------+  +------------------------+  +--------------------------+ |\n"
        "+---------------------------------------------------------------------------------------+"
    )
    add_callout(doc, arch_diagram, title="SYSTEM ARCHITECTURE DIAGRAM (3-TIER LOCAL-FIRST EDGE HYBRID)")

    add_h2("3.2 Clean Architecture & Layer Decoupling")
    doc.add_paragraph(
        "Inside the Flutter application, the codebase is strictly organized according to Clean Architecture principles:\n"
        "• Presentation Layer: Screens, custom animated widgets, and ChangeNotifier providers that consume use cases.\n"
        "• Domain Layer: Pure Dart entity models, value objects, domain-level failure definitions, and isolated Use Case classes.\n"
        "• Data Layer: Repository implementations, remote data sources (Cloud Functions client, REST clients), local data sources (SQLite), and ML data sources."
    )

    # =========================================================================
    # 5. PROJECT FOLDER AND FILE STRUCTURE
    # =========================================================================
    add_h1("4. Project Folder & File Structure")
    doc.add_paragraph(
        "The project strictly adheres to modular separation. Table 4.1 outlines the primary directories and their architectural functions."
    )
    
    dir_table = doc.add_table(rows=1, cols=3)
    dir_table.rows[0].cells[0].paragraphs[0].text = "Directory / Path"
    dir_table.rows[0].cells[1].paragraphs[0].text = "Architectural Role"
    dir_table.rows[0].cells[2].paragraphs[0].text = "Key Components & Purpose"
    
    dir_data = [
        ("lib/core/config/", "Configuration & Secrets", "app_secrets.dart, khaya_language_config.dart. Manages API keys, Remote Config fallback, and language registries."),
        ("lib/core/theme/", "Design System", "app_colors.dart, app_theme.dart. Encapsulates color palettes, typography, card shapes, and theme extensions."),
        ("lib/core/utils/", "Cross-Cutting Utilities", "image_quality_analyzer.dart, retry_utils.dart, rate_limiter.dart, diagnostic_sanitizer.dart, permission_helper.dart, tts_manager.dart."),
        ("lib/data/local/", "Local Persistence Layer", "database_helper.dart, pending_sync_queue.dart. SQLite table DDL, schema migrations, and sync queuing."),
        ("lib/data/ml/", "Machine Learning Runtime", "crop_disease_classifier.dart. TFLite model loading, ByteData tensor allocation, and soft voting ensemble."),
        ("lib/data/remote/", "Remote Network Services", "cloud_functions_service.dart, ghana_nlp_service.dart, gemini_cloud_ai_service.dart, cloudinary_service.dart."),
        ("lib/data/repositories/", "Repository Implementations", "detection_repository_impl.dart, weather_repository_impl.dart, community_repository_impl.dart, risk_repository_impl.dart."),
        ("lib/domain/models/", "Domain Entities", "detection_result.dart, treatment_plan.dart, disease_risk.dart, reporter_trust_stats.dart, community_post.dart."),
        ("lib/domain/usecases/", "Business Use Cases", "scan_crop_usecase.dart, get_home_data_usecase.dart, get_risk_assessment_usecase.dart, login_usecase.dart."),
        ("lib/l10n/", "Localization Dictionaries", "app_en.arb, app_tw.arb, app_ee.arb, app_dag.arb. Vernacular translations for all UI strings."),
        ("lib/presentation/screens/", "UI Screen Controllers", "scanner/, analysing/, result/, outbreak_map/, home/, community/, history/, treatment_tracker/, settings/."),
        ("lib/presentation/components/", "Reusable UI Widgets", "voice_dictation_button.dart, farm_health_ring.dart, confidence_bar.dart, severity_badge.dart, primary_button.dart."),
        ("functions/", "Backend Serverless Code", "index.js, package.json. Node.js 20 Firebase Cloud Functions with Secret Manager integration."),
        ("test/", "Automated Test Suites", "623 automated tests across core, data, domain, presentation, regression, security, and integration suites.")
    ]
    for row_item in dir_data:
        r = dir_table.add_row()
        for idx, text in enumerate(row_item):
            r.cells[idx].paragraphs[0].text = text
    style_table(dir_table)

    # =========================================================================
    # 6. UI/UX DESIGN & ACCESSIBILITY
    # =========================================================================
    add_h1("5. UI/UX Design System & Accessibility Engineering")
    doc.add_paragraph(
        "CropGuard AI's user interface is engineered according to human-centered design principles for field environments. "
        "Farming conditions involve intense sunlight glare, muddy hands, and users with varying levels of literacy. "
        "The interface incorporates high-contrast visual cues, large touch targets, micro-animations, and bidirectional vernacular audio."
    )
    
    add_h2("5.1 Screen Inventory & Navigation Architecture")
    doc.add_paragraph(
        "The app is navigated through an intuitive Bottom Navigation Bar combined with a declarative GoRouter / AppRouter structure. "
        "The primary screens include:"
    )
    screens = [
        ("Dashboard (Home Screen): ", "Displays a high-level Farm Health Ring widget, current agrometeorology risk forecast, 7-day disease trend charts, and recent activity logs."),
        ("Camera Scanner & Live Viewport: ", "Provides a real-time viewfinder with an animated focus reticle, lighting and blur quality validation bars, and dual single/batch image capture options."),
        ("Analysing Screen: ", "Delivers a radar-pulse scanning micro-animation while background TFLite inference, soft-voting ensemble heuristics, and image quality checks execute."),
        ("Diagnosis & Treatment Result Screen: ", "Presents disease classification title, confidence percentage bar, severity indicator badge, localized symptom breakdown, organic/chemical treatment plans, and TTS voice advisory playback."),
        ("Low-Confidence / Secondary Advisory Screen: ", "Triggered automatically when on-device confidence is below 65%, presenting a soft-failure advisor and offering an instant Google Gemini 1.5 Flash cloud second opinion."),
        ("Outbreak Surveillance Map: ", "An interactive OpenStreetMap displaying clustered disease hotspots with color-coded severity rings and distance calculation to the farmer's current coordinates."),
        ("Community Knowledge Exchange: ", "A peer-to-peer farmer forum featuring post moderation, disease reporting, image uploads, and reporter trust badges."),
        ("Chemical Dosage Calculator: ", "An interactive utility calculating precise fungicide/pesticide dilution ratios based on farm acreage, water tank capacity, and chemical concentration.")
    ]
    for s_title, s_desc in screens:
        p = doc.add_paragraph(style='List Bullet')
        p.add_run(s_title).bold = True
        p.add_run(s_desc)

    add_h2("5.2 Accessibility & Voice Dictation Component")
    doc.add_paragraph(
        "To empower non-literate farmers, CropGuard introduces the VoiceDictationButton component (lib/presentation/components/voice_dictation_button.dart). "
        "When tapped, the button captures 16kHz PCM audio from the device microphone and submits it to Khaya AI ASR v3 for transcription. "
        "Similarly, every diagnostic recommendation can be spoken aloud in the farmer's native dialect (Twi, Ewe, or Dagbani) via TtsManager."
    )

    # =========================================================================
    # 7. FRONTEND DEVELOPMENT & STATE MANAGEMENT
    # =========================================================================
    add_h1("6. Frontend Implementation & State Architecture")
    doc.add_paragraph(
        "The client application is built with Flutter 3.x using the Provider state management pattern. "
        "Each functional screen is decoupled into a presentation View and a ChangeNotifier ViewModel / Provider."
    )
    
    add_h2("6.1 State Management Workflow (ScannerProvider Case Study)")
    doc.add_paragraph(
        "The ScannerProvider (lib/presentation/screens/scanner/scanner_provider.dart) coordinates camera capture, image validation, "
        "background ML execution, and error boundary handling. Below is a structural code analysis of the core execution method:"
    )
    
    scanner_snippet = (
        "// ScannerProvider.analyseAndSave() — Orchestrates Edge Diagnosis\n"
        "Future<DetectionResult?> analyseAndSave(File imageFile, String cropType) async {\n"
        "  _setLoading(true);\n"
        "  try {\n"
        "    // Step 1: Pre-inference Image Quality Analysis\n"
        "    final quality = await ImageQualityAnalyzer.analyze(imageFile);\n"
        "    if (quality.isBlurry || quality.isTooDark) {\n"
        "      _errorMessage = 'Image quality too low: please capture with better lighting.';\n"
        "      return null;\n"
        "    }\n"
        "    // Step 2: Execute Use Case (TFLite Inference + Risk-Weighting)\n"
        "    final result = await _scanCropUseCase.execute(imageFile, cropType);\n"
        "    // Step 3: Local Persistence & Optimistic Sync Queueing\n"
        "    await _detectionRepository.saveDetection(result);\n"
        "    _lastResult = result;\n"
        "    return result;\n"
        "  } catch (e, stack) {\n"
        "    AppLogger.e('Scan execution failed', e, stack);\n"
        "    _errorMessage = 'Diagnostic error occurred. Please try again.';\n"
        "    return null;\n"
        "  } finally {\n"
        "    _setLoading(false);\n"
        "  }\n"
        "}"
    )
    add_callout(doc, scanner_snippet, title="CODE SNIPPET: SCANNER PROVIDER DIAGNOSTIC PIPELINE", border_color="1565C0", bg_color="E3F2FD")

    # =========================================================================
    # 8. BACKEND DEVELOPMENT & CLOUD FUNCTIONS
    # =========================================================================
    add_h1("7. Backend Development & Serverless Microservices")
    doc.add_paragraph(
        "The backend is constructed as a serverless suite of Firebase Cloud Functions v2 running on Node.js 20. "
        "The backend acts as a hardened security proxy, executing administrative Firestore mutations, running rate-limiting algorithms, "
        "and managing Secret Manager API keys."
    )
    
    add_h2("7.1 API Endpoint Catalog")
    doc.add_paragraph(
        "Table 7.1 details the serverless endpoints implemented in functions/index.js."
    )
    
    api_table = doc.add_table(rows=1, cols=5)
    api_table.rows[0].cells[0].paragraphs[0].text = "Function / Endpoint"
    api_table.rows[0].cells[1].paragraphs[0].text = "Trigger Type"
    api_table.rows[0].cells[2].paragraphs[0].text = "Purpose"
    api_table.rows[0].cells[3].paragraphs[0].text = "Auth Requirement"
    api_table.rows[0].cells[4].paragraphs[0].text = "External Integration"
    
    api_data = [
        ("analyzeCropWithGemini", "Callable (HTTPS)", "Multimodal second opinion for low-confidence scans", "Firebase Auth JWT", "Google Gemini 1.5 Flash API"),
        ("synthesizeGhanaNlp", "Callable (HTTPS)", "Proxy text-to-speech synthesis (TTS v2)", "Firebase Auth JWT", "Khaya AI TTS v2 (/tts/v2/synthesize)"),
        ("transcribeGhanaNlp", "Callable (HTTPS)", "Proxy speech-to-text transcription (ASR v3)", "Firebase Auth JWT", "Khaya AI ASR v3 (/asr/v3/transcribe)"),
        ("translateGhanaNlp", "Callable (HTTPS)", "Proxy text translation between EN and local dialects", "Firebase Auth JWT", "Khaya AI Translation v2 (/translate)"),
        ("verifyOutbreak", "Callable (HTTPS)", "Extension officer community outbreak validation & trust scoring", "Admin / Auth JWT", "Cloud Firestore"),
        ("aggregateHotspots", "Callable (HTTPS)", "Compute spatial clustering & severity weights for outbreaks", "Firebase Auth JWT", "Cloud Firestore"),
        ("onDocumentWritten", "Firestore Trigger", "Auto-sanitize inappropriate community posts and moderate content", "Internal Trigger", "ContentModerationEngine"),
        ("onUserDeleted", "Identity Trigger", "GDPR-compliant cascading removal of farmer data upon account deletion", "Internal Trigger", "Cloud Firestore / Storage")
    ]
    for row_item in api_data:
        r = api_table.add_row()
        for idx, text in enumerate(row_item):
            r.cells[idx].paragraphs[0].text = text
    style_table(api_table)

    # =========================================================================
    # 9. DATABASE DESIGN
    # =========================================================================
    add_h1("8. Database Design: Cloud Firestore & Local SQLite")
    doc.add_paragraph(
        "CropGuard implements a hybrid database model utilizing Cloud Firestore for global cloud document synchronization "
        "and SQLite (via sqflite) for zero-latency local relational storage."
    )
    
    add_h2("8.1 SQLite Local Database Schema (lib/data/local/database_helper.dart)")
    doc.add_paragraph("The local SQLite database defines four core tables with foreign keys and optimized B-tree indexes:")
    
    db_table = doc.add_table(rows=1, cols=4)
    db_table.rows[0].cells[0].paragraphs[0].text = "Table Name"
    db_table.rows[0].cells[1].paragraphs[0].text = "Primary Key"
    db_table.rows[0].cells[2].paragraphs[0].text = "Key Columns"
    db_table.rows[0].cells[3].paragraphs[0].text = "Storage Purpose"
    
    db_data = [
        ("detections", "id (TEXT)", "crop_type, disease_name, confidence, severity, image_path, timestamp, is_synced, latitude, longitude", "Stores all local scans with offline image paths and diagnostic metrics."),
        ("treatment_records", "id (TEXT)", "detection_id (FK), treatment_type, application_date, dosage, notes, completed", "Tracks progress of organic/chemical treatments applied to infected plots."),
        ("pending_sync", "id (INTEGER PK AUTO)", "entity_type, entity_id, operation, payload_json, created_at, retry_count", "FIFO synchronization queue storing mutations waiting for network reconnection."),
        ("fields", "id (TEXT)", "name, crop_type, acreage, planting_date, latitude, longitude", "Farmer field and plot boundaries used for spatial risk mapping.")
    ]
    for row_item in db_data:
        r = db_table.add_row()
        for idx, text in enumerate(row_item):
            r.cells[idx].paragraphs[0].text = text
    style_table(db_table)

    add_h2("8.2 Cloud Firestore Document Collections")
    doc.add_paragraph(
        "In the cloud tier, Firestore maintains the following collections:\n"
        "• `users/{uid}`: Farmer profiles, regional location, contact data, trust statistics, and language preferences.\n"
        "• `detections/{detectionId}`: Cloud-synchronized disease records with verified GPS coordinates and diagnosis payloads.\n"
        "• `community_posts/{postId}`: Peer-to-peer discussion threads, crop photos, and extension comments with moderation flags.\n"
        "• `outbreak_hotspots/{hotspotId}`: Pre-aggregated disease clusters computed by serverless background triggers."
    )

    # =========================================================================
    # 10. AUTHENTICATION & SECURITY
    # =========================================================================
    add_h1("9. Security Architecture & Threat Defense")
    doc.add_paragraph(
        "Security is implemented across all tiers of CropGuard AI to safeguard user privacy, prevent unauthorized API usage, "
        "and defend against common mobile and cloud attack vectors."
    )
    
    add_h2("9.1 Multi-Layered Defense Mechanisms")
    sec_points = [
        ("Zero-Secret Client Binaries: ", "Master API credentials (GHANA_NLP_SUBSCRIPTION_KEY, GEMINI_API_KEY) are never embedded into the Flutter APK. All third-party calls are routed through authenticated Cloud Functions accessing GCP Secret Manager."),
        ("Biometric & Session Authentication: ", "Integrated with Firebase Authentication (Email/Password, Google Sign-In, Anonymous Guest) and local biometric unlocking (Fingerprint / Face ID via local_auth)."),
        ("Diagnostic & Error Log Sanitizer (DiagnosticSanitizer): ", "Custom regex-based log interceptor (lib/core/utils/diagnostic_sanitizer.dart) that strips bearer tokens, passwords, GPS coordinates, and raw base64 chunks before logs are written or transmitted."),
        ("Server-Side Request Forgery (SSRF) Prevention: ", "The SafeImageDownloader utility (lib/core/utils/safe_image_downloader.dart) validates URL schemes, prohibits private IP ranges (127.0.0.1, 10.0.0.0/8, 192.168.0.0/16, link-local 169.254.0.0/16), and blocks DNS rebinding."),
        ("Automated Content Moderation: ", "ContentModerationHelper evaluates community text for abusive terms, spam keywords, and malicious links, flagging posts for moderation prior to Firestore persistence."),
        ("Client-Side & Server-Side Rate Limiting: ", "A token-bucket RateLimiter algorithm (lib/core/utils/rate_limiter.dart) prevents denial-of-wallet and quota exhaustion attacks on voice synthesis and cloud diagnostic endpoints.")
    ]
    for s_title, s_desc in sec_points:
        p = doc.add_paragraph(style='List Bullet')
        p.add_run(s_title).bold = True
        p.add_run(s_desc)

    # =========================================================================
    # 11. AI / MACHINE LEARNING SYSTEM
    # =========================================================================
    add_h1("10. Artificial Intelligence & Machine Learning Pipeline")
    doc.add_paragraph(
        "CropGuard AI's core intelligence is powered by a dual-tier Edge-to-Cloud Deep Learning architecture."
    )
    
    add_h2("10.1 On-Device MobileNetV2 Architecture")
    doc.add_paragraph(
        "The on-device model is based on an optimized MobileNetV2 architecture with inverted residual blocks and linear bottlenecks. "
        "The model is quantized to Float32/Int8 TFLite format (`assets/cropguard_plant_disease.tflite`), consuming only 14.8 MB of disk space "
        "and executing on mobile CPU/NNAPI hardware in 60–120ms."
    )
    doc.add_paragraph(
        "The model is trained to classify 51 agricultural plant disease categories across major African staple crops, including:\n"
        "• Tomato: Bacterial Spot, Early Blight, Late Blight, Leaf Mold, Septoria Leaf Spot, Target Spot, Yellow Leaf Curl Virus, Mosaic Virus, Healthy.\n"
        "• Cassava: Bacterial Blight, Brown Streak Disease, Green Mottle, Mosaic Disease, Healthy.\n"
        "• Cocoa: Black Pod Disease (Phytophthora), Swollen Shoot Virus, Mirid Bug Damage, Healthy.\n"
        "• Maize (Corn): Common Rust, Northern Leaf Blight, Gray Leaf Spot, Fall Armyworm Damage, Healthy.\n"
        "• Pepper / Bell Pepper: Bacterial Spot, Healthy.\n"
        "• Potato: Early Blight, Late Blight, Healthy."
    )

    add_h2("10.2 Image Quality Pre-Processing & Soft-Voting Ensemble")
    doc.add_paragraph(
        "Before feeding image bytes into the neural network, the ImageQualityAnalyzer performs Laplacian variance blur detection "
        "and RGB luminance histogram analysis. If the image passes quality gates, it is normalized to [-1.0, 1.0] and resized to 224x224x3. "
        "The RiskWeightedClassifier evaluates the output softmax distribution, applying epidemiological priors based on local weather humidity "
        "to weight high-risk pathogens."
    )

    add_h2("10.3 Secondary Multimodal Cloud AI (Google Gemini 1.5 Flash)")
    doc.add_paragraph(
        "When the top edge prediction confidence falls below the 65% threshold (or in cases where multi-pathogen co-infection is suspected), "
        "the client prompts the farmer to request a Cloud AI second opinion. Google Gemini 1.5 Flash processes the full-resolution crop photograph "
        "and returns structured JSON containing diagnostic reasoning, pathogen root causes, organic cultural controls, and chemical active ingredients."
    )

    # =========================================================================
    # 12. TESTING & QUALITY ASSURANCE
    # =========================================================================
    add_h1("11. Testing Methodology & Verification Results")
    doc.add_paragraph(
        "To ensure uncompromising production quality and zero regression risks, CropGuard AI underwent exhaustive automated and manual verification. "
        "The automated test suite contains 623 individual tests across seven specialized test suites, achieving 100% pass rate."
    )
    
    add_h2("11.1 Test Suite Breakdown")
    
    test_table = doc.add_table(rows=1, cols=4)
    test_table.rows[0].cells[0].paragraphs[0].text = "Test Suite Domain"
    test_table.rows[0].cells[1].paragraphs[0].text = "File Path"
    test_table.rows[0].cells[2].paragraphs[0].text = "Test Focus & Coverage"
    test_table.rows[0].cells[3].paragraphs[0].text = "Tests Passed"
    
    test_data = [
        ("Ghana NLP & API Regression", "test/data/remote/ghana_nlp_service_test.dart", "Enforces ASR v3, TTS v2, Translation v2 contracts, language registry, and audio caching", "25 / 25 Passed"),
        ("Cloud Functions Client", "test/data/remote/cloud_functions_service_test.dart", "Verifies authenticated proxy calls, token injection, and response parsing", "7 / 7 Passed"),
        ("Offline Sync & Queue", "test/data/sync/offline_sync_correctness_test.dart", "Validates FIFO queuing, network reconnect drain, and conflict resolution", "45 / 45 Passed"),
        ("ML & Classification Heuristics", "test/data/ml/crop_disease_classifier_test.dart", "Tests tensor parsing, soft-voting ensemble, and risk-weighted thresholds", "60 / 60 Passed"),
        ("Security & Vulnerabilities", "test/security/firestore_rules_validation_test.dart", "Tests SSRF protection, sanitization, rate limiting, and user block mechanics", "55 / 55 Passed"),
        ("Presentation & State (MVVM)", "test/presentation/screens/*/*_test.dart", "Validates all ViewModels, form validation, error state transitions, and UI flows", "320 / 320 Passed"),
        ("Full App Integration & A11y", "test/integration/ & test/presentation/components/", "End-to-end integration workflows, high-contrast badges, and screen reader labels", "111 / 111 Passed")
    ]
    for row_item in test_data:
        r = test_table.add_row()
        for idx, text in enumerate(row_item):
            r.cells[idx].paragraphs[0].text = text
    style_table(test_table)

    add_h2("11.2 Key Test Scenarios Table")
    
    scen_table = doc.add_table(rows=1, cols=5)
    scen_table.rows[0].cells[0].paragraphs[0].text = "Test Case ID"
    scen_table.rows[0].cells[1].paragraphs[0].text = "Scenario Description"
    scen_table.rows[0].cells[2].paragraphs[0].text = "Input / Stimulus"
    scen_table.rows[0].cells[3].paragraphs[0].text = "Expected Result"
    scen_table.rows[0].cells[4].paragraphs[0].text = "Status"
    
    scen_data = [
        ("TC-ML-01", "Edge TFLite Inference", "Valid Cocoa Black Pod leaf photo", "Classified as Cocoa Black Pod with >90% confidence in <150ms", "PASSED"),
        ("TC-ML-02", "Low Confidence Handling", "Unclear blurred leaf photo", "ImageQualityAnalyzer flags blur; prompts user or triggers Gemini fallback", "PASSED"),
        ("TC-OFF-01", "Offline Scan Persistence", "Device in Airplane Mode; perform crop scan", "Scan saved locally in SQLite; queued in pending_sync table", "PASSED"),
        ("TC-OFF-02", "Automatic Background Sync", "Re-enable WiFi/Cellular telemetry", "Pending sync queue drains automatically; Firestore updated with remote IDs", "PASSED"),
        ("TC-LANG-01", "Twi Voice Dictation", "16kHz PCM audio of spoken Twi notes", "Khaya ASR v3 returns transcribed Twi text; inserted into notes controller", "PASSED"),
        ("TC-LANG-02", "Vernacular TTS Synthesis", "Diagnostic advisory string in Dagbani", "Khaya TTS v2 synthesizes audio; cached on disk and played via AudioPlayer", "PASSED"),
        ("TC-SEC-01", "Diagnostic Log Sanitization", "Exception log containing auth token & GPS", "DiagnosticSanitizer redacts secrets into [REDACTED_SECRET]", "PASSED"),
        ("TC-SEC-02", "SSRF Defense in Image Loader", "Image URL pointing to 127.0.0.1/admin", "SafeImageDownloader blocks private IP and throws SecurityException", "PASSED")
    ]
    for row_item in scen_data:
        r = scen_table.add_row()
        for idx, text in enumerate(row_item):
            r.cells[idx].paragraphs[0].text = text
    style_table(scen_table)

    # =========================================================================
    # 13. DEPLOYMENT & PRODUCTION SPECIFICATIONS
    # =========================================================================
    add_h1("12. Deployment Process & Production Engineering")
    doc.add_paragraph(
        "CropGuard AI is built for continuous delivery to Google Play Store and Apple App Store."
    )
    
    add_h2("12.1 Build Artifacts & Android Compilation")
    doc.add_paragraph(
        "The Android deployment package is compiled via Flutter Gradle tooling:\n"
        "• Debug Build: `flutter build apk --debug` -> Generates `build/app/outputs/flutter-apk/app-debug.apk`.\n"
        "• Release Build: `flutter build apk --release` -> Generates optimized APK with R8 code shrinking and ProGuard rules.\n"
        "• Play Store Bundle: `flutter build appbundle --release` -> Generates `.aab` for dynamic feature delivery."
    )
    
    add_h2("12.2 Backend Deployment (Firebase Cloud Functions)")
    doc.add_paragraph(
        "The serverless backend is deployed using the Firebase CLI:\n"
        "```bash\n"
        "firebase deploy --only functions,firestore:rules,storage\n"
        "```\n"
        "All secrets are provisioned in GCP Secret Manager and bound to Cloud Functions v2 via environment declarations."
    )

    # =========================================================================
    # 14. CHALLENGES, LIMITATIONS & FUTURE WORK
    # =========================================================================
    add_h1("13. Challenges Encountered, Technical Solutions & Limitations")
    
    add_h2("13.1 Technical Challenges & Engineering Solutions")
    chall = [
        ("Mobile TFLite Binary Size vs 51-Class Accuracy: ", "Challenge: Supporting 51 plant disease classes with full floating-point weights resulted in an excessively large model. Solution: Applied post-training quantization and inverted residual bottleneck architecture, compressing the model to 14.8 MB with <1.5% accuracy loss."),
        ("Deprecation of Ghana NLP v1/v2 APIs: ", "Challenge: Provider console deprecated legacy v1/v2 endpoints, causing breaking changes. Solution: Executed Phase 9A contract definition and migrated backend proxies to ASR v3 and TTS v2 with centralized version constants and single-point speaker registries."),
        ("SQLite vs Firestore Data Mapping: ", "Challenge: Discrepancy between SQL relational integrity and NoSQL document flexibility. Solution: Implemented the PendingSyncQueue mapper converting Firestore timestamps and nested JSON objects into structured SQLite DDL rows with conflict-free optimistic concurrency.")
    ]
    for c_title, c_desc in chall:
        p = doc.add_paragraph(style='List Bullet')
        p.add_run(c_title).bold = True
        p.add_run(c_desc)

    add_h2("13.2 System Limitations")
    doc.add_paragraph(
        "• Visual Occlusion & Leaf Focus: The on-device classifier requires a relatively clear, unobstructed view of a single affected leaf; dense multi-plant canopies require targeted framing.\n"
        "• Agrometeorological Spatial Resolution: Weather risk calculations rely on Open-Meteo's regional grid resolution (~10 km); micro-climatic greenhouse variations require manual observation."
    )

    add_h2("13.3 Future Roadmap")
    doc.add_paragraph(
        "1. Multi-Crop Bounding Box Object Detection using YOLOv8-Nano on Edge TPU.\n"
        "2. Voice-first Conversational AI Bot allowing bidirectional Q&A in natural Twi, Ewe, and Dagbani.\n"
        "3. Integration with drone imagery for automated wide-acre farm disease surveying."
    )

    # =========================================================================
    # 15. CONCLUSION
    # =========================================================================
    add_h1("14. Conclusion")
    doc.add_paragraph(
        "CropGuard AI represents a significant technological leap in mobile agricultural diagnostic engineering. "
        "By uniting zero-latency edge deep learning, hybrid multimodal cloud reasoning, localized epidemiological mapping, "
        "and indigenous African language audio interfaces, the system delivers an empowering, life-changing tool into the hands "
        "of smallholder farmers. The project demonstrates the practical viability of deploying advanced artificial intelligence "
        "to solve real-world food security challenges in resource-constrained environments."
    )

    # =========================================================================
    # 16. APPENDIX
    # =========================================================================
    add_h1("15. Appendix & Reference Architecture")
    doc.add_paragraph("Summary of important commands for testing and building CropGuard AI:")
    
    app_cmds = (
        "# 1. Run Complete Automated Test Suite (623 Tests)\n"
        "flutter test --no-pub\n\n"
        "# 2. Build Android Debug APK\n"
        "flutter build apk --debug\n\n"
        "# 3. Build Android Production Release APK\n"
        "flutter build apk --release\n\n"
        "# 4. Deploy Firebase Cloud Functions & Security Rules\n"
        "firebase deploy --only functions,firestore:rules,storage"
    )
    add_callout(doc, app_cmds, title="APPENDIX A: SYSTEM CLI COMMANDS", border_color="455A64", bg_color="ECEFF1")

    output_path = "/Users/kwameyeboah/Downloads/CropGuardAI-main/CropGuardAI-main/docs/CropGuard_AI_Final_Year_Project_Report.docx"
    doc.save(output_path)
    print(f"Report successfully generated at: {output_path}")

if __name__ == "__main__":
    create_report()
