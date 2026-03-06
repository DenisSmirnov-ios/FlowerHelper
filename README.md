# Green Friend

iOS-приложение «Зеленый помощник» для ухода за комнатными растениями.

## Что умеет
- Подоконник с карточками растений и датами полива
- Поиск и добавление растений из локальной базы
- Fallback-поиск через WFO
- Уведомления о поливе
- Виджет с актуальным статусом полива
- Поддержка светлой и темной темы

## Технологии
- SwiftUI
- SwiftData
- WidgetKit
- UserNotifications

## Структура проекта
- `GreenFriend/` — исходники приложения и ресурсы
- `GreenFriend.xcodeproj/` — Xcode-проект

## Запуск локально
1. Открыть `GreenFriend.xcodeproj` в Xcode.
2. Выбрать схему `GreenFriend`.
3. Запустить на симуляторе или устройстве.

## CI
GitHub Actions workflow: `.github/workflows/ios-build.yml`.
Сборка выполняется для iOS Simulator без подписи.

## Лицензия
MIT, см. [LICENSE](LICENSE).
