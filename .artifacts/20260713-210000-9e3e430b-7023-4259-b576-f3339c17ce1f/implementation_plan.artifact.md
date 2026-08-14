# Implementation Plan - Super Admin Management System

This plan outlines the overhaul of the Admin Panel into a comprehensive Super Admin Dashboard with full operational control over shops, riders, areas, and system settings.

## Proposed Changes

### 1. Enhanced Admin Dashboard (Tab 1: Dashboard)
- **Real-time Analytics**: Display Total Sales (Lifetime), Today's Sales, Active Orders, Total Businesses, and Total Riders.
- **Visual Statistics**: Card-based UI with modern icons and color coding.

### 2. Business Management (Tab 2: Shops)
- **Onboarding**: Form to add new businesses (Name, Category, Owner Phone, Address, Logo).
- **Control**: Actions to Approve, Suspend, Block, or force Online/Offline any shop.
- **Edit**: Ability to update any shop's details on their behalf.

### 3. Rider Management (Tab 3: Riders)
- **Onboarding**: Form to add new riders (Name, Phone, Area).
- **Earnings & Stats**: View total deliveries and ratings for each rider.
- **Status Control**: Block/Unblock riders or change their active status.

### 4. Area & Service Management (Tab 4: Areas)
- **Area Control**: Add/Edit delivery areas.
- **Service Fees**: Update Delivery Charges and Minimum Order amounts per area.
- **Commission**: Set Rider Commission rates.

### 5. System Settings (Tab 5: Settings)
- **Maintenance Mode**: One-tap switch to put the entire app into "Maintenance Mode" (disabling ordering for customers).
- **System Announcements**: Broadcast messages to all users.
- **Global Config**: GST/Tax percentage and Platform Fee settings.

## Suggestions for Advanced Admin Control
1. **Rider Live Tracking**: See current positions of all online riders on a map.
2. **Order Dispatch Console**: Manually reassign orders to different riders if needed.
3. **Financial Reports**: Export sales and earnings data to Excel/PDF.
4. **Push Notification Center**: Send custom notifications to specific user groups.

## Technical Tasks
- **`admin_repository.dart`**: Add methods for sales aggregation, rider onboarding, and system settings update.
- **UI Screens**: Create 5 dedicated tab screens and refactor `AdminHomeScreen`.

## Verification Plan

### Manual Verification
1. **Analytics Test**: Verify that 'Today's Sales' matches the sum of orders delivered today.
2. **Onboarding Test**: Add a test shop and verify it appears in the Customer App.
3. **Maintenance Test**: Turn on Maintenance Mode and verify customers see a "Down for Maintenance" screen.
4. **Control Test**: Block a shop and verify it becomes invisible to customers.
