import os
import docx
from docx.shared import Inches, Pt
from docx.enum.text import WD_ALIGN_PARAGRAPH

def update_document():
    doc_path = 'GROUP 2 CHAPTER 1 TO CHAPTER 4.docx'
    if not os.path.exists(doc_path):
        print(f"Error: {doc_path} not found.")
        return

    doc = docx.Document(doc_path)
    
    # Locate Section 3.14.2
    target_idx = None
    for i, p in enumerate(doc.paragraphs):
        if '3.14.2' in p.text or 'Figure 3.10' in p.text:
            target_idx = i
            break

    if target_idx is None:
        print("Could not find section 3.14.2 in document.")
        return

    print(f"Found target paragraph at index {target_idx}: {doc.paragraphs[target_idx].text}")

    # Find Figure 3.10 paragraph
    fig_idx = None
    for i in range(target_idx, min(target_idx + 10, len(doc.paragraphs))):
        if 'Figure 3.10' in doc.paragraphs[i].text:
            fig_idx = i
            break

    if fig_idx is not None:
        p_fig = doc.paragraphs[fig_idx]
        
        # Clear existing text and format as caption
        p_fig.text = ""
        p_fig.alignment = WD_ALIGN_PARAGRAPH.CENTER
        
        # Insert ER Diagram Image
        run_img1 = p_fig.add_run()
        run_img1.add_picture('CropGuard_ER_Diagram_Chen.png', width=Inches(6.2))
        
        # Caption 1
        p_cap1 = p_fig.insert_paragraph_before()
        p_cap1.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run_cap1 = p_cap1.add_run("Figure 3.10: Entity-Relationship (ER) Diagram — Chen Notation")
        run_cap1.font.bold = True
        run_cap1.font.size = Pt(105 // 10)
        run_cap1.font.name = 'Calibri'
        
        # Insert Relational Database Schema Diagram
        p_schema = p_fig.insert_paragraph_before()
        p_schema.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run_img2 = p_schema.add_run()
        run_img2.add_picture('CropGuard_Database_Schema.png', width=Inches(6.2))
        
        # Caption 2
        p_cap2 = p_fig.insert_paragraph_before()
        p_cap2.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run_cap2 = p_cap2.add_run("Figure 3.11: Relational Database Schema & Field Constraints (SQLite v14)")
        run_cap2.font.bold = True
        run_cap2.font.size = Pt(105 // 10)
        run_cap2.font.name = 'Calibri'

        print("Successfully embedded ER diagram and Relational Schema images into docx.")

    doc.save(doc_path)
    print(f"Saved updated document to {doc_path}")

if __name__ == "__main__":
    update_document()
