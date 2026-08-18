import os
import matplotlib.pyplot as plt
import matplotlib.patches as patches

def draw_chen_er_diagram_group6_style():
    fig, ax = plt.subplots(figsize=(15, 10), dpi=300)
    ax.set_xlim(0, 150)
    ax.set_ylim(0, 100)
    ax.axis('off')
    
    # White background
    fig.patch.set_facecolor('white')
    ax.set_facecolor('white')

    def draw_entity(x, y, text, width=24, height=9):
        rect = patches.Rectangle((x - width/2, y - height/2), width, height,
                                 linewidth=1.8, edgecolor='black', facecolor='white')
        ax.add_patch(rect)
        ax.text(x, y, text, fontsize=10, fontweight='bold', ha='center', va='center', color='black')

    def draw_relationship(x, y, text, width=18, height=8):
        diamond = patches.Polygon([
            (x, y + height/2),
            (x + width/2, y),
            (x, y - height/2),
            (x - width/2, y)
        ], linewidth=1.5, edgecolor='black', facecolor='white')
        ax.add_patch(diamond)
        ax.text(x, y, text, fontsize=8.5, fontweight='bold', ha='center', va='center', color='black')

    def draw_attribute(x, y, text, is_pk=False, width=15, height=5.5):
        ellipse = patches.Ellipse((x, y), width, height,
                                  linewidth=1.2, edgecolor='black', facecolor='white')
        ax.add_patch(ellipse)
        if is_pk:
            ax.text(x, y, text, fontsize=7.5, fontweight='bold', ha='center', va='center', color='black')
            ax.plot([x - len(text)*0.35, x + len(text)*0.35], [y - 1.4, y - 1.4], color='black', lw=1.2)
        else:
            ax.text(x, y, text, fontsize=7.5, ha='center', va='center', color='black')

    def draw_line(x1, y1, x2, y2, label=None, label_pos=0.5):
        ax.plot([x1, x2], [y1, y2], color='black', lw=1.2, zorder=1)
        if label:
            lx = x1 + (x2 - x1) * label_pos
            ly = y1 + (y2 - y1) * label_pos
            ax.text(lx, ly + 1.5, label, fontsize=9, fontweight='bold', color='black', ha='center', va='center')

    # Entities
    entities = {
        'USERS': (25, 75),
        'DETECTIONS': (75, 75),
        'TREATMENT_PLANS': (125, 75),
        'OUTBREAK_REPORTS': (25, 25),
        'PENDING_SYNC_QUEUE': (75, 25),
        'TREATMENT_TASKS': (125, 25)
    }

    for ent, (x, y) in entities.items():
        draw_entity(x, y, ent)

    # Relationships
    draw_relationship(50, 75, "PERFORMS")
    draw_line(25 + 12, 75, 50 - 9, 75, label="1", label_pos=0.3)
    draw_line(50 + 9, 75, 75 - 12, 75, label="N", label_pos=0.7)

    draw_relationship(100, 75, "GENERATES")
    draw_line(75 + 12, 75, 100 - 9, 75, label="1", label_pos=0.3)
    draw_line(100 + 9, 75, 125 - 12, 75, label="1", label_pos=0.7)

    draw_relationship(125, 50, "CONTAINS")
    draw_line(125, 75 - 4.5, 125, 50 + 4, label="1", label_pos=0.3)
    draw_line(125, 50 - 4, 125, 25 + 4.5, label="N", label_pos=0.7)

    draw_relationship(25, 50, "SUBMITS")
    draw_line(25, 75 - 4.5, 25, 50 + 4, label="1", label_pos=0.3)
    draw_line(25, 50 - 4, 25, 25 + 4.5, label="N", label_pos=0.7)

    draw_relationship(75, 50, "ENQUEUES")
    draw_line(75, 75 - 4.5, 75, 50 + 4, label="1", label_pos=0.3)
    draw_line(75, 50 - 4, 75, 25 + 4.5, label="N", label_pos=0.7)

    # Attributes
    u_attrs = [
        ("user_id", True, (10, 90)),
        ("display_name", False, (25, 93)),
        ("email", False, (40, 90)),
        ("role", False, (10, 62)),
        ("created_at", False, (40, 62))
    ]
    for name, is_pk, pos in u_attrs:
        draw_line(entities['USERS'][0], entities['USERS'][1], pos[0], pos[1])
        draw_attribute(pos[0], pos[1], name, is_pk)

    d_attrs = [
        ("id", True, (60, 94)),
        ("userId", False, (70, 96)),
        ("imagePath", False, (80, 96)),
        ("diseaseLabel", False, (90, 94)),
        ("confidence", False, (56, 82)),
        ("severity", False, (94, 82)),
        ("cropType", False, (58, 62)),
        ("timestamp", False, (92, 62))
    ]
    for name, is_pk, pos in d_attrs:
        draw_line(entities['DETECTIONS'][0], entities['DETECTIONS'][1], pos[0], pos[1])
        draw_attribute(pos[0], pos[1], name, is_pk)

    tp_attrs = [
        ("plan_id", True, (110, 90)),
        ("detection_id", False, (125, 93)),
        ("disease_label", False, (140, 90)),
        ("is_completed", False, (140, 62)),
        ("created_at", False, (110, 62))
    ]
    for name, is_pk, pos in tp_attrs:
        draw_line(entities['TREATMENT_PLANS'][0], entities['TREATMENT_PLANS'][1], pos[0], pos[1])
        draw_attribute(pos[0], pos[1], name, is_pk)

    ob_attrs = [
        ("report_id", True, (8, 38)),
        ("user_id", False, (25, 40)),
        ("crop_type", False, (42, 38)),
        ("latitude", False, (10, 12)),
        ("longitude", False, (25, 10)),
        ("timestamp", False, (40, 12))
    ]
    for name, is_pk, pos in ob_attrs:
        draw_line(entities['OUTBREAK_REPORTS'][0], entities['OUTBREAK_REPORTS'][1], pos[0], pos[1])
        draw_attribute(pos[0], pos[1], name, is_pk)

    ps_attrs = [
        ("sync_id", True, (60, 38)),
        ("entity_type", False, (75, 40)),
        ("payload_json", False, (90, 38)),
        ("created_at", False, (60, 12)),
        ("status", False, (90, 12))
    ]
    for name, is_pk, pos in ps_attrs:
        draw_line(entities['PENDING_SYNC_QUEUE'][0], entities['PENDING_SYNC_QUEUE'][1], pos[0], pos[1])
        draw_attribute(pos[0], pos[1], name, is_pk)

    tt_attrs = [
        ("task_id", True, (110, 38)),
        ("plan_id", False, (125, 40)),
        ("title", False, (140, 38)),
        ("due_date", False, (110, 12)),
        ("is_done", False, (140, 12))
    ]
    for name, is_pk, pos in tt_attrs:
        draw_line(entities['TREATMENT_TASKS'][0], entities['TREATMENT_TASKS'][1], pos[0], pos[1])
        draw_attribute(pos[0], pos[1], name, is_pk)

    plt.tight_layout()
    plt.savefig('CropGuard_ER_Diagram_Chen.png', bbox_inches='tight', dpi=300)
    plt.close()
    print("Saved monochrome CropGuard_ER_Diagram_Chen.png")

def draw_relational_schema_group6_style():
    fig, ax = plt.subplots(figsize=(15, 11), dpi=300)
    ax.set_xlim(0, 150)
    ax.set_ylim(0, 110)
    ax.axis('off')
    fig.patch.set_facecolor('white')
    ax.set_facecolor('white')

    def draw_table(x, y, title, columns):
        width = 44
        row_height = 4.0
        header_height = 5.0
        total_height = header_height + (len(columns) + 1) * row_height

        # Table header
        header_rect = patches.Rectangle((x, y - header_height), width, header_height,
                                        linewidth=1.2, edgecolor='black', facecolor='#E0E0E0')
        ax.add_patch(header_rect)
        ax.text(x + width/2, y - header_height/2, title, fontsize=9.5, fontweight='bold', color='black', ha='center', va='center')

        # Sub-header
        sub_y = y - header_height - 3.2
        sub_rect = patches.Rectangle((x, sub_y), width, 3.2, linewidth=1, edgecolor='black', facecolor='#F5F5F5')
        ax.add_patch(sub_rect)
        ax.text(x + 2, sub_y + 1.6, "Key", fontsize=7.5, fontweight='bold', color='black', va='center')
        ax.text(x + 8, sub_y + 1.6, "Column Name", fontsize=7.5, fontweight='bold', color='black', va='center')
        ax.text(x + 26, sub_y + 1.6, "Data Type", fontsize=7.5, fontweight='bold', color='black', va='center')
        ax.text(x + 36, sub_y + 1.6, "Constraints", fontsize=7.5, fontweight='bold', color='black', va='center')

        # Rows
        curr_y = sub_y
        for i, (key, col, dtype, constr) in enumerate(columns):
            curr_y -= row_height
            r_rect = patches.Rectangle((x, curr_y), width, row_height, linewidth=0.8, edgecolor='black', facecolor='white')
            ax.add_patch(r_rect)

            ax.text(x + 2, curr_y + row_height/2, key, fontsize=7.5, fontweight='bold', color='black', va='center')
            ax.text(x + 8, curr_y + row_height/2, col, fontsize=7.5, fontweight='bold' if key=='PK' else 'normal', color='black', va='center')
            ax.text(x + 26, curr_y + row_height/2, dtype, fontsize=7, color='black', va='center')
            ax.text(x + 36, curr_y + row_height/2, constr, fontsize=6.5, color='black', va='center')
        
        return {
            'x': x, 'y': y, 'width': width, 'total_height': total_height,
            'col_y': lambda idx: sub_y - (idx + 0.5) * row_height
        }

    users_cols = [
        ('PK', 'user_id', 'TEXT', 'PRIMARY KEY'),
        ('', 'display_name', 'TEXT', 'NOT NULL'),
        ('', 'email', 'TEXT', 'NOT NULL'),
        ('', 'role', 'TEXT', 'DEFAULT farmer'),
        ('', 'created_at', 'INTEGER', 'NOT NULL')
    ]

    detections_cols = [
        ('PK', 'id', 'INTEGER', 'AUTOINCREMENT'),
        ('FK', 'userId', 'TEXT', 'REF users(user_id)'),
        ('', 'imagePath', 'TEXT', 'NOT NULL'),
        ('', 'diseaseLabel', 'TEXT', 'NOT NULL'),
        ('', 'confidence', 'REAL', 'NOT NULL'),
        ('', 'severity', 'TEXT', 'DEFAULT unclear'),
        ('', 'isHealthy', 'INTEGER', 'NOT NULL'),
        ('', 'cropType', 'TEXT', 'NOT NULL'),
        ('', 'timestamp', 'INTEGER', 'NOT NULL')
    ]

    treatment_plans_cols = [
        ('PK', 'plan_id', 'TEXT', 'PRIMARY KEY'),
        ('FK', 'detection_id', 'INTEGER', 'REF detections(id)'),
        ('', 'disease_label', 'TEXT', 'NOT NULL'),
        ('', 'crop_type', 'TEXT', 'NOT NULL'),
        ('', 'created_at', 'INTEGER', 'NOT NULL'),
        ('', 'is_completed', 'INTEGER', 'DEFAULT 0')
    ]

    treatment_tasks_cols = [
        ('PK', 'task_id', 'TEXT', 'PRIMARY KEY'),
        ('FK', 'plan_id', 'TEXT', 'REF plans(plan_id)'),
        ('', 'title', 'TEXT', 'NOT NULL'),
        ('', 'description', 'TEXT', 'NULLABLE'),
        ('', 'due_date', 'INTEGER', 'NOT NULL'),
        ('', 'is_done', 'INTEGER', 'DEFAULT 0')
    ]

    outbreak_cols = [
        ('PK', 'report_id', 'TEXT', 'PRIMARY KEY'),
        ('FK', 'user_id', 'TEXT', 'REF users(user_id)'),
        ('', 'crop_type', 'TEXT', 'NOT NULL'),
        ('', 'disease_label', 'TEXT', 'NOT NULL'),
        ('', 'latitude', 'REAL', 'NOT NULL'),
        ('', 'longitude', 'REAL', 'NOT NULL'),
        ('', 'timestamp', 'INTEGER', 'NOT NULL')
    ]

    sync_cols = [
        ('PK', 'sync_id', 'INTEGER', 'AUTOINCREMENT'),
        ('FK', 'detection_id', 'INTEGER', 'REF detections(id)'),
        ('', 'entity_type', 'TEXT', 'NOT NULL'),
        ('', 'payload_json', 'TEXT', 'NOT NULL'),
        ('', 'status', 'TEXT', 'DEFAULT pending'),
        ('', 'created_at', 'INTEGER', 'NOT NULL')
    ]

    t_users = draw_table(6, 102, "users", users_cols)
    t_detections = draw_table(53, 102, "detections", detections_cols)
    t_plans = draw_table(100, 102, "treatment_plans", treatment_plans_cols)

    t_outbreak = draw_table(6, 46, "outbreak_reports", outbreak_cols)
    t_sync = draw_table(53, 46, "pending_sync_queue", sync_cols)
    t_tasks = draw_table(100, 46, "treatment_tasks", treatment_tasks_cols)

    def draw_rel_line(x1, y1, x2, y2, card="1:N"):
        ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                    arrowprops=dict(arrowstyle="-|>", color='black', lw=1.5))
        mid_x = (x1 + x2) / 2
        mid_y = (y1 + y2) / 2
        ax.text(mid_x, mid_y + 1, card, fontsize=8, fontweight='bold', color='black',
                bbox=dict(boxstyle="round,pad=0.2", facecolor="white", edgecolor="black", lw=0.8))

    draw_rel_line(t_users['x'] + t_users['width'], t_users['col_y'](0),
                  t_detections['x'], t_detections['col_y'](1), card="1:N")

    draw_rel_line(t_detections['x'] + t_detections['width'], t_detections['col_y'](0),
                  t_plans['x'], t_plans['col_y'](1), card="1:1")

    draw_rel_line(t_plans['x'] + t_plans['width']/2, t_plans['y'] - t_plans['total_height'],
                  t_tasks['x'] + t_tasks['width']/2, t_tasks['y'] - 4, card="1:N")

    draw_rel_line(t_users['x'] + t_users['width']/2, t_users['y'] - t_users['total_height'],
                  t_outbreak['x'] + t_outbreak['width']/2, t_outbreak['y'] - 4, card="1:N")

    draw_rel_line(t_detections['x'] + t_detections['width']/2, t_detections['y'] - t_detections['total_height'],
                  t_sync['x'] + t_sync['width']/2, t_sync['y'] - 4, card="1:N")

    plt.tight_layout()
    plt.savefig('CropGuard_Database_Schema.png', bbox_inches='tight', dpi=300)
    plt.close()
    print("Saved monochrome CropGuard_Database_Schema.png")

if __name__ == "__main__":
    draw_chen_er_diagram_group6_style()
    draw_relational_schema_group6_style()
