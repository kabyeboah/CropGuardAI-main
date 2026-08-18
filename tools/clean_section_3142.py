import docx
from docx.shared import Inches, Pt
from docx.enum.text import WD_ALIGN_PARAGRAPH

def clean_section():
    doc_path = 'GROUP 2 CHAPTER 1 TO CHAPTER 4.docx'
    doc = docx.Document(doc_path)

    # Remove paragraphs around 473-482 that are duplicate captions or empty lines
    target_idx = None
    for i, p in enumerate(doc.paragraphs):
        if '3.14.2' in p.text:
            target_idx = i
            break

    if target_idx is None:
        print("Target not found")
        return

    # Delete paragraphs from target_idx+1 up to 'Project Methods to be Employed'
    end_idx = None
    for i in range(target_idx + 1, len(doc.paragraphs)):
        if 'Project Methods to be Employed' in doc.paragraphs[i].text:
            end_idx = i
            break

    if end_idx is None:
        print("End marker not found")
        return

    print(f"Clearing paragraphs between {target_idx+1} and {end_idx-1}")
    
    # Delete paragraphs in reverse order
    for i in range(end_idx - 1, target_idx, -1):
        p = doc.paragraphs[i]._element
        p.getparent().remove(p)

    # Now insert fresh structured content after target_idx paragraph (Section 3.14.2)
    p_head = doc.paragraphs[target_idx]
    
    # 1. Descriptive paragraph
    p_desc = p_head.insert_paragraph_before()
    p_head._element.getparent().replace(p_desc._element, p_head._element) # place head first
    
    p_body = doc.add_paragraph()
    p_body.text = ("CropGuard AI uses an offline-first relational persistence model combining an embedded local "
                   "SQLite database (cropguard.db, schema v14) for instantaneous zero-latency offline access and "
                   "Cloud Firestore for multi-region cloud backup and community sharing. The schema comprises six "
                   "primary normalized tables: USERS (AppUser authentication profiles), DETECTIONS (diagnostic scan logs "
                   "with SHA-256 integrity checksums), TREATMENT_PLANS (personalized recovery schedules), TREATMENT_TASKS "
                   "(actionable daily recovery tasks), OUTBREAK_REPORTS (aggregated regional disease alerts), and "
                   "PENDING_SYNC_QUEUE (atomic offline mutation queue). Figure 3.10 illustrates the Entity-Relationship (ER) "
                   "diagram using Chen notation, and Figure 3.11 details the relational database schema and field constraints.")
    p_body.style = 'Normal'
    # Move p_body right after p_head
    p_head._element.addnext(p_body._element)

    # 2. Image 1: Figure 3.10 ER Diagram
    p_img1 = doc.add_paragraph()
    p_img1.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run_img1 = p_img1.add_run()
    run_img1.add_picture('CropGuard_ER_Diagram_Chen.png', width=Inches(6.2))
    p_body._element.addnext(p_img1._element)

    # 3. Caption 1
    p_cap1 = doc.add_paragraph()
    p_cap1.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run_cap1 = p_cap1.add_run("Figure 3.10: Entity-Relationship (ER) Diagram — Chen Notation")
    run_cap1.font.bold = True
    run_cap1.font.size = Pt(10)
    run_cap1.font.name = 'Calibri'
    p_img1._element.addnext(p_cap1._element)

    # 4. Image 2: Figure 3.11 Relational Schema
    p_img2 = doc.add_paragraph()
    p_img2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run_img2 = p_img2.add_run()
    run_img2.add_picture('CropGuard_Database_Schema.png', width=Inches(6.2))
    p_cap1._element.addnext(p_img2._element)

    # 5. Caption 2
    p_cap2 = doc.add_paragraph()
    p_cap2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run_cap2 = p_cap2.add_run("Figure 3.11: Relational Database Schema & Field Constraints (SQLite v14)")
    run_cap2.font.bold = True
    run_cap2.font.size = Pt(10)
    run_cap2.font.name = 'Calibri'
    p_img2._element.addnext(p_cap2._element)

    doc.save(doc_path)
    print("Section 3.14.2 cleaned and updated successfully!")

if __name__ == "__main__":
    clean_section()
