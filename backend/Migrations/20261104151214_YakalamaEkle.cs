using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class YakalamaEkle : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Yakalamalar",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Metin = table.Column<string>(type: "character varying(5000)", maxLength: 5000, nullable: true),
                    FotografId = table.Column<Guid>(type: "uuid", nullable: true),
                    Hedef = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Durum = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    YakalandiAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Yakalamalar", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Yakalamalar_Dosyalar_FotografId",
                        column: x => x.FotografId,
                        principalTable: "Dosyalar",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Yakalamalar_Durum_YakalandiAt",
                table: "Yakalamalar",
                columns: new[] { "Durum", "YakalandiAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Yakalamalar_FotografId",
                table: "Yakalamalar",
                column: "FotografId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Yakalamalar");
        }
    }
}
