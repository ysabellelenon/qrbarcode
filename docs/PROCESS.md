# QR Barcode System - User Guide

## Overview
This application helps manage and track items through QR codes and barcodes. There are two main types of users:
1. Engineers - who set up and manage the system
2. Operators - who perform the daily scanning operations

## How the System Works

### For Engineers

#### Setting Up New Items
1. Log in with your engineer credentials
2. Click "New Register" to add a new item
3. Fill in the basic information:
   - Item Name
   - Revision Number
   - How many codes need to be scanned for this item

4. For each code, you'll specify:
   - If it needs to track counting (like serial numbers) or just verify content
   - What information should be on the label

5. Review all details before saving
6. Once saved, operators can start scanning these items

#### Managing Users
1. Go to Account Settings
2. You can:
   - Create new user accounts
   - Edit existing users
   - Remove users when needed

### For Operators

#### Starting Your Work Day
1. Log in with your operator credentials
2. You'll need to scan:
   - The item name you're working with
   - The P.O (Purchase Order) number
   - The total quantity you need to scan

#### Scanning Process
1. First, scan the article label
   - This contains important information about the batch
   - The system checks if it matches your entered item and PO number

2. Start scanning individual items
   - The screen will show you:
     * How many items you need to scan in total
     * How many items per box
     * Your current progress
   - Each scan will show immediately as:
     * Green ✓ for good scans
     * Red X for any problems

3. When a box is full:
   - You'll get a notification
   - Click "Scan New Article Label" to start the next box
   - Previous box information is saved automatically

4. Progress Tracking
   - You can see how many items you've scanned
   - How many were good/no good
   - How close you are to finishing

#### If Something Goes Wrong
1. Click the Emergency Stop button
2. An engineer will need to:
   - Log in to verify the stop
   - Add notes about what happened
3. The system will save all progress up to that point

### Important Notes
- The system prevents common mistakes like:
  * Scanning the same item twice
  * Scanning more items than needed
  * Scanning items in the wrong order
- All scans are saved automatically
- You can't scan more items than the total quantity needed
- If you're unsure about anything, ask an engineer for help

This system helps ensure quality control and proper tracking of all items scanned. Each scan is recorded and can be reviewed later if needed. 