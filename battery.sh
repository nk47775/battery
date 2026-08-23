#!/bin/bash
C="\033[36m"; G="\033[32m"; R="\033[31m"; Y="\033[33m"; N="\033[0m"

# ज़रूरी पैकेज इंस्टॉल करना
if ! command -v termux-battery-status &> /dev/null || ! command -v jq &> /dev/null; then
  echo -e "${Y}ज़रूरी API पैकेज इंस्टॉल हो रहे हैं... ⏳${N}"
  pkg install termux-api jq -y > /dev/null 2>&1
fi

PID_FILE="$HOME/.batt_monitor.pid"

# बैकग्राउंड सर्विस का कोड जनरेट करना
monitor_code() {
  cat << 'EOF' > "$HOME/.batt_monitor.sh"
#!/bin/bash
while true; do
  b_info=$(termux-battery-status 2>/dev/null)
  b_pct=$(echo "$b_info" | jq -r '.percentage')
  b_status=$(echo "$b_info" | jq -r '.status')

  if [[ "$b_pct" -ge 100 && "$b_status" == "CHARGING" ]] || [[ "$b_status" == "FULL" ]]; then
    termux-vibrate -d 2000
    termux-notification --title "🔋 Battery 100% Full" --content "Please disconnect the charger to save battery health." --priority max
    termux-tts-speak "Attention! Battery is fully charged. Please unplug the charger."
  elif [[ "$b_pct" -le 15 && "$b_status" == "DISCHARGING" ]]; then
    termux-vibrate -d 2000
    termux-notification --title "🪫 Battery Low ($b_pct%)" --content "Please plug in the charger immediately!" --priority max
    termux-tts-speak "Warning! Battery is very low. Please connect the charger."
  fi
  sleep 60
done
EOF
  chmod +x "$HOME/.batt_monitor.sh"
}

start_monitor() {
  if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    echo -e "\n${Y}⚠️ अलार्म सर्विस पहले से ही बैकग्राउंड में चल रही है!${N}"
  else
    monitor_code
    nohup bash "$HOME/.batt_monitor.sh" > /dev/null 2>&1 &
    echo $! > "$PID_FILE"
    echo -e "\n${G}✅ बैटरी अलार्म बैकग्राउंड में चालू हो गया! (Termux बंद करने पर भी चलेगा)${N}"
  fi
}

stop_monitor() {
  if [ -f "$PID_FILE" ]; then
    kill $(cat "$PID_FILE") 2>/dev/null
    rm "$PID_FILE"
    echo -e "\n${R}🛑 बैकग्राउंड अलार्म सर्विस बंद कर दी गई है!${N}"
  else
    echo -e "\n${Y}⚠️ कोई अलार्म सर्विस नहीं चल रही है।${N}"
  fi
}

test_alarm() {
  echo -e "\n${Y}टेस्टिंग अलार्म... कृपया फोन का वॉल्यूम (Media) फुल रखें! ⏳${N}"
  termux-notification --title "🔔 Test Alarm" --content "This is a test notification." --priority max
  termux-vibrate -d 1500
  termux-tts-speak "This is a test alarm. Your tool is working perfectly."
  sleep 2
  echo -e "${G}✅ टेस्ट पूरा हुआ!${N}"
}

show_status() {
  echo -e "\n${Y}बैटरी हार्डवेयर स्कैन हो रहा है... ⏳${N}\n"
  b_info=$(termux-battery-status 2>/dev/null)
  
  if [ -z "$b_info" ]; then
    echo -e "${R}❌ एरर: Termux:API ऐप इंस्टॉल नहीं है या काम नहीं कर रही है!${N}"
    return
  fi

  b_pct=$(echo "$b_info" | jq -r '.percentage')
  b_status=$(echo "$b_info" | jq -r '.status')
  b_health=$(echo "$b_info" | jq -r '.health')
  b_temp=$(echo "$b_info" | jq -r '.temperature')

  echo -e "🔹 बैटरी लेवल:     ${G}${b_pct}%${N}"
  echo -e "🔹 चार्जिंग स्टेटस: ${C}${b_status}${N}"
  echo -e "🔹 बैटरी हेल्थ:     ${G}${b_health}${N}"
  echo -e "🔹 फोन का तापमान:  ${Y}${b_temp}°C${N}\n"
}

while true; do
  clear
  echo -e "${C}====================================${N}"
  echo -e "${Y} 🔋 सुप्रीम बैटरी & चार्जिंग अलार्म 🔋 ${N}"
  echo -e "${C}====================================${N}\n"

  if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    echo -e "स्टेटस: ${G}🟢 बैकग्राउंड अलार्म ON है${N}\n"
  else
    echo -e "स्टेटस: ${R}🔴 बैकग्राउंड अलार्म OFF है${N}\n"
  fi

  echo -e "1. 📊 लाइव बैटरी स्टेटस (Health & Temp) देखें"
  echo -e "2. ▶️ बैकग्राउंड अलार्म चालू करें (Full & Low Battery)"
  echo -e "3. ⏹️ बैकग्राउंड अलार्म बंद करें"
  echo -e "4. 🔊 अलार्म टेस्ट करें (Voice & Vibrate Check)"
  echo -e "q. ❌ बाहर निकलें\n"

  read -p "विकल्प चुनें: " opt
  [[ "$opt" == "q" ]] && break

  if [ "$opt" == "1" ]; then
    show_status
    read -p "वापस जाने के लिए Enter दबाएं..."
  elif [ "$opt" == "2" ]; then
    start_monitor
    read -p "वापस जाने के लिए Enter दबाएं..."
  elif [ "$opt" == "3" ]; then
    stop_monitor
    read -p "वापस जाने के लिए Enter दबाएं..."
  elif [ "$opt" == "4" ]; then
    test_alarm
    read -p "वापस जाने के लिए Enter दबाएं..."
  else
    echo -e "${R}❌ गलत विकल्प!${N}"
    sleep 1; continue
  fi
done
