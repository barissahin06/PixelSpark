import sys, re

file_path = r"c:\Users\Murathan Eren Kale\Documents\GitHub\PixelSpark\our-game\management\scenes\LudusScreen.tscn"
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add the new GIF texture as an ext_resource at the top
gif_resource = '[ext_resource type="Texture2D" uid="uid://cm4abcd12345" path="res://assets/ui/pixel_art_Roman_Murmillo_gladiator_full_body_idle_breathing-idle_east.gif" id="3_murmillo"]'
if 'pixel_art_Roman_Murmillo' not in content:
    content = content.replace('[ext_resource type="Texture2D"', gif_resource + '\n[ext_resource type="Texture2D"', 1)

# Modify ActionContainer and Details Panel: We hide the entire MainContent
content = content.replace('[node name="MainContent" type="HBoxContainer"', '[node name="MainContent" type="HBoxContainer"\nvisible = false')

# Add absolute buttons directly under the root node
absolute_nodes = """
[node name="GladiatorsContainer" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -200.0
grow_horizontal = 2
grow_vertical = 0
theme_override_constants/separation = 20
alignment = 1

[node name="DoorActions" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="MarketplaceMenuButton" type="Button" parent="DoorActions"]
layout_mode = 0
offset_left = 100.0
offset_top = 300.0
offset_right = 300.0
offset_bottom = 350.0
text = "Marketplace"

[node name="FeedMenuButton" type="Button" parent="DoorActions"]
layout_mode = 0
offset_left = 400.0
offset_top = 300.0
offset_right = 600.0
offset_bottom = 350.0
text = "Feed Gladiators"

[node name="TrainMenuButton" type="Button" parent="DoorActions"]
layout_mode = 0
offset_left = 700.0
offset_top = 300.0
offset_right = 900.0
offset_bottom = 350.0
text = "Train Gladiators"

[node name="ActionModals" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="FeedModal" type="ColorRect" parent="ActionModals"]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.784314)

[node name="Panel" type="PanelContainer" parent="ActionModals/FeedModal"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -150.0
offset_right = 200.0
offset_bottom = 150.0
grow_horizontal = 2
grow_vertical = 2

[node name="MarginContainer" type="MarginContainer" parent="ActionModals/FeedModal/Panel"]
layout_mode = 2
theme_override_constants/margin_left = 16
theme_override_constants/margin_top = 16
theme_override_constants/margin_right = 16
theme_override_constants/margin_bottom = 16

[node name="VBox" type="VBoxContainer" parent="ActionModals/FeedModal/Panel/MarginContainer"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="Label" type="Label" parent="ActionModals/FeedModal/Panel/MarginContainer/VBox"]
layout_mode = 2
theme_override_font_sizes/font_size = 24
text = "Select Gladiator to Feed"
horizontal_alignment = 1

[node name="ScrollContainer" type="ScrollContainer" parent="ActionModals/FeedModal/Panel/MarginContainer/VBox"]
layout_mode = 2
size_flags_vertical = 3

[node name="FeedList" type="VBoxContainer" parent="ActionModals/FeedModal/Panel/MarginContainer/VBox/ScrollContainer"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/separation = 10

[node name="CloseFeedButton" type="Button" parent="ActionModals/FeedModal/Panel/MarginContainer/VBox"]
layout_mode = 2
text = "Close"

[node name="TrainListModal" type="ColorRect" parent="ActionModals"]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.784314)

[node name="Panel" type="PanelContainer" parent="ActionModals/TrainListModal"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -150.0
offset_right = 200.0
offset_bottom = 150.0
grow_horizontal = 2
grow_vertical = 2

[node name="MarginContainer" type="MarginContainer" parent="ActionModals/TrainListModal/Panel"]
layout_mode = 2
theme_override_constants/margin_left = 16
theme_override_constants/margin_top = 16
theme_override_constants/margin_right = 16
theme_override_constants/margin_bottom = 16

[node name="VBox" type="VBoxContainer" parent="ActionModals/TrainListModal/Panel/MarginContainer"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="Label" type="Label" parent="ActionModals/TrainListModal/Panel/MarginContainer/VBox"]
layout_mode = 2
theme_override_font_sizes/font_size = 24
text = "Select Gladiator to Train"
horizontal_alignment = 1

[node name="ScrollContainer" type="ScrollContainer" parent="ActionModals/TrainListModal/Panel/MarginContainer/VBox"]
layout_mode = 2
size_flags_vertical = 3

[node name="TrainList" type="VBoxContainer" parent="ActionModals/TrainListModal/Panel/MarginContainer/VBox/ScrollContainer"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/separation = 10

[node name="CloseTrainListButton" type="Button" parent="ActionModals/TrainListModal/Panel/MarginContainer/VBox"]
layout_mode = 2
text = "Close"
"""

if '[node name="GladiatorsContainer"' not in content:
    content = content.replace('[node name="MarginContainer" type="MarginContainer" parent="."]', absolute_nodes + '\n[node name="MarginContainer" type="MarginContainer" parent="."]', 1)

new_connections = """
[connection signal="pressed" from="DoorActions/MarketplaceMenuButton" to="." method="_on_marketplace_menu_pressed"]
[connection signal="pressed" from="DoorActions/FeedMenuButton" to="." method="_on_feed_menu_pressed"]
[connection signal="pressed" from="DoorActions/TrainMenuButton" to="." method="_on_train_menu_pressed"]
[connection signal="pressed" from="ActionModals/FeedModal/Panel/MarginContainer/VBox/CloseFeedButton" to="." method="_on_close_feed_pressed"]
[connection signal="pressed" from="ActionModals/TrainListModal/Panel/MarginContainer/VBox/CloseTrainListButton" to="." method="_on_close_train_list_pressed"]
"""

if '_on_marketplace_menu_pressed' not in content:
    content += new_connections

# Disable visibility of original MarketplaceButton, FeedButton, TrainButton for safety instead of deleting
content = content.replace('[node name="MarketplaceButton" type="Button" parent="MarginContainer/VBoxContainer/BottomActions"]\n', '[node name="MarketplaceButton" type="Button" parent="MarginContainer/VBoxContainer/BottomActions"]\nvisible = false\n')
content = content.replace('[node name="FeedButton" type="Button" parent="MarginContainer/VBoxContainer/MainContent/DetailsPanel/VBoxContainer/ActionsContainer"]\n', '[node name="FeedButton" type="Button" parent="MarginContainer/VBoxContainer/MainContent/DetailsPanel/VBoxContainer/ActionsContainer"]\nvisible = false\n')
content = content.replace('[node name="TrainButton" type="Button" parent="MarginContainer/VBoxContainer/MainContent/DetailsPanel/VBoxContainer/ActionsContainer"]\n', '[node name="TrainButton" type="Button" parent="MarginContainer/VBoxContainer/MainContent/DetailsPanel/VBoxContainer/ActionsContainer"]\nvisible = false\n')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Patch applied successfully.')
