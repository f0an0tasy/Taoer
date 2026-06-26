import { preferences } from "@kit.ArkData"
const PREFERENCES_NAME = 'myStore'
export class TalkHistoryInfo{

  myMsgArr:string[] = []
  reasonContent:string[]=[]
  content:string[]=[]

  static instance:TalkHistoryInfo

  private talkHistoryInfo:TalkHistoryInfo[] = []

  dataPreferences: preferences.Preferences | null = null;

  public static getInstance(){
    if (!TalkHistoryInfo.instance) {
      TalkHistoryInfo.instance = new TalkHistoryInfo()
    }
    return TalkHistoryInfo.instance
  }

  async saveTalk(myMsgArr: string[], reasonContent: string[], content: string[]) {
    this.dataPreferences = AppStorage.get('pf') as preferences.Preferences
    if (!this.dataPreferences) {
      return
    }

    let all = new TalkHistoryInfo()
    all.myMsgArr = [...myMsgArr]
    all.reasonContent = [...reasonContent]
    all.content = [...content]

    await this.dataPreferences.put('all', all)
    await this.dataPreferences.flush()
  }

}