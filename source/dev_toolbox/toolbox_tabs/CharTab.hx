package dev_toolbox.toolbox_tabs;

import flixel.addons.transition.FlxTransitionableState;
import dev_toolbox.file_explorer.FileExplorer;
import dev_toolbox.week_editor.WeekCharacterSettings;
import openfl.display.BitmapData;
import flixel.tweens.FlxTween;
using StringTools;

import flixel.util.FlxColor;
import flixel.FlxG;
import dev_toolbox.week_editor.CreateWeekWizard;
import flixel.addons.ui.*;
import haxe.Json;
import sys.io.File;
import flixel.text.FlxText;
import flixel.FlxSprite;
import StoryMenuState.FNFWeek;
import StoryMenuState.WeeksJson;
import sys.FileSystem;

class CharTab extends ToolboxTab {
    public var character:Character = null;
    public var danceTime:Float = 0;
    public var legend:FlxUIText;
    public var anims_text:FlxUIText;

    public var anims:Array<String> = [];
    public var selectedAnim:Int = 0;

    public override function new(x:Float, y:Float, home:ToolboxHome) {
        super(x, y, "chars", home);

        FileSystem.createDirectory('${Paths.getModsFolder()}\\${ToolboxHome.selectedMod}\\characters');
        var chars =[
            for(folder in FileSystem.readDirectory('${Paths.getModsFolder()}\\${ToolboxHome.selectedMod}\\characters'))
                if (FileSystem.isDirectory('${Paths.getModsFolder()}\\${ToolboxHome.selectedMod}\\characters\\$folder'))
                    folder
        ];
        var radios = new FlxUIRadioGroup(10, 10, chars, chars, function(char) {
            
        }, 25, 300, 640);
        var charLayer = 0;
        var previewButton = new FlxUIButton(10, 670, "Preview", function() {
            if (character != null) {
                remove(character);
                character.destroy();
            }
            character = new Character(0, 0, CoolUtil.getCharacterFullString(radios.selectedLabel, ToolboxHome.selectedMod));
            insert(charLayer, character);
            character.screenCenter(Y);
            character.x = 320 + ((1280 - 320) / 2) - (character.width / 2);
            character.setPosition(character.x - character.camOffset.x, character.y - character.camOffset.y);
            anims = [];
            @:privateAccess
            var it = character.animation._animations.keys();
            while (it.hasNext()) {
                anims.push(it.next());
            }
            anims.sort(function(a, b) {return (a.toUpperCase() < b.toUpperCase()) ? -1 : ((a.toUpperCase() > b.toUpperCase()) ? 1 : 0);});
        });
        previewButton.resize(67, 20);
        add(previewButton);
        var createButton = new FlxUIButton(previewButton.x + previewButton.width + 10, 670, "Create", function() {
            state.openSubState(new CharacterCreator());
        });
        createButton.resize(67, 20);
        var editButton = new FlxUIButton(createButton.x + createButton.width + 10, 670, "Edit", function() {
            if (radios.selectedId == null || radios.selectedId == "") {
                state.openSubState(ToolboxMessage.showMessage("Error", "No character was selected."));
                return;
            }
            // if (!FileSystem.exists('${Paths.getModsFolder()}\\${ToolboxHome.selectedMod}\\characters\\${radios.selectedId}\\Character.json')) {
            //     state.openSubState(ToolboxMessage.showMessage("Error", "Character editor currently only works with characters with JSON files."));
            //     return;
            // }
            dev_toolbox.character_editor.CharacterEditor.fromFreeplay = false;
            FlxG.switchState(new dev_toolbox.character_editor.CharacterEditor(radios.selectedId));
        });
        editButton.resize(67, 20);
        var deleteButton = new FlxUIButton(editButton.x + editButton.width + 10, 670, "Delete", function() {
            if (radios.selectedId == null || radios.selectedId == "") {
                state.openSubState(ToolboxMessage.showMessage("Error", "No character was selected."));
                return;
            }
            state.openSubState(new ToolboxMessage("Delete Character", 'Are you sure you want to delete ${radios.selectedId} ? This operation is irreversible.', [
                {
                    label: "Yes",
                    onClick: function(t) {
                        CoolUtil.deleteFolder('${Paths.getModsFolder()}\\${ToolboxHome.selectedMod}\\characters\\${radios.selectedId}\\');
                        FileSystem.deleteDirectory('${Paths.getModsFolder()}\\${ToolboxHome.selectedMod}\\characters\\${radios.selectedId}\\');
                        state.openSubState(ToolboxMessage.showMessage("Success", '${radios.selectedId} was successfully deleted.', function() {
                            FlxTransitionableState.skipNextTransIn = true;
                            FlxTransitionableState.skipNextTransOut = true;
                            FlxG.resetState();
                        }));
                    }
                },
                {
                    label: "No",
                    onClick: function(t) {}
                }
            ]));
        });
        deleteButton.resize(67, 20);
        add(createButton);
        add(editButton);
        add(deleteButton);
        add(radios);
        legend = new FlxUIText(330, 666, FlxG.width - 330, "[Up/Down] Change animation | [Space] Play Animation | [Enter] Flip");
        legend.size = 20;
        legend.color = FlxColor.BLACK;
        add(legend);

        anims_text = new FlxUIText(330, 0, FlxG.width - 330, "");
        anims_text.size = 12;
        anims_text.color = FlxColor.BLACK;
        add(anims_text);

        charLayer = 1;
    }

    public override function tabUpdate(elapsed) {
        if (character == null) {
            anims_text.text = "Select a character...";
            return;
        }
        var t = (selectedAnim == 0 ? "> " : "") + "Dance animation";
        for (k=>e in anims) {
            if (k == selectedAnim - 1) {
                t += '\n> ${anims[k]}';
            } else {
                t += '\n${anims[k]}';
            }
        }
        anims_text.text = t;
        if (FlxG.keys.justPressed.UP) {
            selectedAnim--;
        }
        if (FlxG.keys.justPressed.DOWN) {
            selectedAnim++;
        }
        if (FlxG.keys.justPressed.ENTER) {
            character.flipX = !character.flipX;
        }
        if (selectedAnim > anims.length) selectedAnim = 0;
        if (selectedAnim < 0) selectedAnim = anims.length;
        if (selectedAnim == 0) {
            danceTime += elapsed;
            if (danceTime > 0.5) {
                danceTime = danceTime % 0.5;
                if (character != null) {
                    character.lastNoteHitTime = -500;
                    character.dance();
                }
            }
        } else {
            if (character.animation.curAnim == null || character.animation.curAnim.name != anims[selectedAnim - 1]) {
                character.playAnim(anims[selectedAnim - 1]);
            }
        }

        if (FlxG.keys.justPressed.SPACE && selectedAnim > 0) {
            character.playAnim(anims[selectedAnim - 1], true);
        }
    }
}