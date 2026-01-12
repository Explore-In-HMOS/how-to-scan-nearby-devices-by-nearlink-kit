import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { scan, manager } from '@kit.NearLinkKit';
import { promptAction } from '@kit.ArkUI';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';

const LOG_TAG: string = 'NearlinkScanner';
const DOMAIN_ID: number = 0x0000;

interface SimpleDevice {
  address: string;
  name: string;
  rssi: number;
}

@Entry
@Component
export struct Index {
  @State nearlinkOn: boolean = false;
  @State scanning: boolean = false;
  @State devices: Array<SimpleDevice> = [];

  private targetManufacturerId: number = 4567;


  aboutToAppear(): void {
    this.reqPermissions().then(() => {
      this.checkNearlinkState();
    });
  }

  aboutToDisappear(): void {
    if (this.scanning) {
      void this.stopScan();
    }
  }

  // --- HELPER TO GET STRING FOR LOGS ---
  private getResString(resource: Resource): string {
    try {
      // YENİ: UIContext üzerinden ResourceManager'a erişim
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      return context.resourceManager.getStringSync(resource);
    } catch (e) {
      return '';
    }
  }

  // --- PERMISSIONS ---
  private async reqPermissions(): Promise<void> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;

      await atManager.requestPermissionsFromUser(context, [
        'ohos.permission.ACCESS_NEARLINK',
        'ohos.permission.ACCESS_BLUETOOTH'
      ]);
      // Log: Permissions Requested
      hilog.info(DOMAIN_ID, LOG_TAG, this.getResString($r('app.string.log_perm_req')));
    } catch (err) {
      hilog.error(DOMAIN_ID, LOG_TAG, `Permission Error: ${(err as BusinessError).message}`);
    }
  }

  private checkNearlinkState(): void {
    try {
      const state: manager.NearlinkState = manager.getState();
      this.nearlinkOn = (state === manager.NearlinkState.STATE_ON);
    } catch (err) {
      hilog.error(DOMAIN_ID, LOG_TAG, `State Error: ${(err as BusinessError).message}`);
    }
  }

  // -------------------- SCANNING OPERATIONS --------------------

  private async startScan() {
    if (!this.nearlinkOn) {
      // Toast: Please enable NearLink...
      promptAction.openToast({ message: $r('app.string.toast_enable_nearlink') });
      return;
    }
    if (this.scanning) {
      return;
    }

    try {
      this.devices = [];
      scan.on('deviceFound', (d) => this.onDeviceFound(d));

      await scan.startScan([{ manufacturerId: this.targetManufacturerId }], { scanMode: 0 });

      this.scanning = true;
      // Log: Scan Started
      hilog.info(DOMAIN_ID, LOG_TAG, this.getResString($r('app.string.log_scan_started')));
    } catch (e) {
      hilog.error(DOMAIN_ID, LOG_TAG, `Start Scan Error: ${JSON.stringify(e)}`);
    }
  }

  private async stopScan() {
    try {
      await scan.stopScan();
      scan.off('deviceFound');
      this.scanning = false;
      // Log: Scan Stopped
      hilog.info(DOMAIN_ID, LOG_TAG, this.getResString($r('app.string.log_scan_stopped')));
    } catch (e) {
      hilog.error(DOMAIN_ID, LOG_TAG, `Stop Scan Error: ${JSON.stringify(e)}`);
    }
  }

  private onDeviceFound(results: Array<scan.ScanResults>) {
    results.forEach((item) => {
      const devName = item.deviceName;

      const dev: SimpleDevice = {
        address: item.address,
        name: devName,
        rssi: item.rssi
      };

      const idx = this.devices.findIndex(d => d.address === dev.address);

      if (idx === -1) {
        this.devices.push(dev);
      } else {
        this.devices[idx] = dev;
      }
    });
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          Text($r('app.string.app_title'))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ top: 30, bottom: 10 })
            .width('90%')

          Row() {
            Text(this.scanning ? $r('app.string.status_scanning') : $r('app.string.status_idle'))
              .fontColor(this.scanning ? '#00FF7F' : '#A0A0A0')
              .fontWeight(FontWeight.Medium)
              .fontSize(16)
          }
          .width('90%')
          .margin({ bottom: 20 })

          Button(this.scanning ? $r('app.string.btn_stop') : $r('app.string.btn_start'))
            .onClick(() => {
              if (this.scanning) {
                this.stopScan();
              } else {
                this.startScan();
              }
            })
            .width('90%')
            .height(50)
            .margin({ bottom: 30 })
            .backgroundColor(this.scanning ? '#FF453A' : '#0A84FF')
            .shadow({ radius: 10, color: this.scanning ? '#FF453A40' : '#0A84FF40' })

          Divider()
            .color('#333333')
            .width('90%')
            .margin({ bottom: 20 })


          Column() {
            if (this.devices.length === 0) {
              Text(this.scanning ? $r('app.string.msg_searching') : $r('app.string.msg_no_devices'))
                .width('100%')
                .textAlign(TextAlign.Center)
                .fontColor('#666666')
                .padding({ top: 40 })
            } else {
              ForEach(this.devices, (dev: SimpleDevice) => {
                Row() {
                  Column() {
                    Text(dev.name || $r('app.string.device_unknown'))
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)

                    Text(dev.address)
                      .fontSize(12)
                      .fontColor('#888888')
                      .margin({ top: 6 })
                      .fontFamily('Monospace')
                  }
                  .alignItems(HorizontalAlign.Start)

                  Blank()

                  Text($r('app.string.rssi_format', dev.rssi))
                    .fontSize(16)
                    .fontColor('#0A84FF')
                    .fontWeight(FontWeight.Bold)
                }
                .width('100%')
                .padding(20)
                .margin({ bottom: 12 })
                .backgroundColor('#1C1C1E')
                .borderRadius(16)
              }, (dev: SimpleDevice) => dev.address)
            }
          }
          .width('90%')
          .padding({ bottom: 50 })
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
      }
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
      .height('100%')
      .backgroundColor('#000000')
    }
    .hideTitleBar(true)
  }
}